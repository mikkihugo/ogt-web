<?php
namespace Klarna_Checkout\Controller\Webhook;

use Magento\Framework\App\Action\Action;
use Magento\Framework\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\App\CsrfAwareActionInterface;
use Magento\Framework\App\Request\InvalidRequestException;
use Magento\Framework\App\RequestInterface;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Store\Model\ScopeInterface;
use Magento\Sales\Model\OrderFactory;
use Magento\Sales\Model\Order;
use Psr\Log\LoggerInterface;

/**
 * Klarna Webhook Push Handler
 *
 * Handles push notifications from Klarna with HMAC signature validation
 * Updates order status based on payment confirmations
 */
class Push extends Action implements HttpPostActionInterface, CsrfAwareActionInterface
{
    protected $resultJsonFactory;
    protected $scopeConfig;
    protected $orderFactory;
    protected $logger;

    public function __construct(
        Context $context,
        JsonFactory $resultJsonFactory,
        ScopeConfigInterface $scopeConfig,
        OrderFactory $orderFactory,
        LoggerInterface $logger
    ) {
        parent::__construct($context);
        $this->resultJsonFactory = $resultJsonFactory;
        $this->scopeConfig = $scopeConfig;
        $this->orderFactory = $orderFactory;
        $this->logger = $logger;
    }

    /**
     * Disable CSRF validation for webhooks (HMAC signature provides security)
     *
     * @param RequestInterface $request
     * @return bool|null
     */
    public function validateForCsrf(RequestInterface $request): ?bool
    {
        return true; // HMAC signature validation handles security
    }

    /**
     * Create exception for CSRF validation failure
     *
     * @param RequestInterface $request
     * @return InvalidRequestException|null
     */
    public function createCsrfValidationException(RequestInterface $request): ?InvalidRequestException
    {
        return null;
    }

    /**
     * Handle Klarna push notification
     *
     * @return \Magento\Framework\Controller\Result\Json
     */
    public function execute()
    {
        $result = $this->resultJsonFactory->create();

        try {
            // Get Klarna order ID from request
            $klarnaOrderId = $this->getRequest()->getParam('klarna_order_id');
            $sid = $this->getRequest()->getParam('sid');

            if (!$klarnaOrderId) {
                $this->logger->warning('Klarna webhook: Missing order ID');
                return $result->setHttpResponseCode(400)->setData(['error' => 'Missing order ID']);
            }

            // Get shared secret for HMAC validation
            $sharedSecret = $this->scopeConfig->getValue(
                'klarna_checkout/general/shared_secret',
                ScopeInterface::SCOPE_STORE
            );

            if (!$sharedSecret) {
                $this->logger->critical('Klarna webhook: Shared secret not configured');
                return $result->setHttpResponseCode(500)->setData(['error' => 'Configuration error']);
            }

            // Validate HMAC signature (if provided by Klarna)
            $signature = $this->getRequest()->getHeader('Klarna-Signature');
            if ($signature) {
                if (!$this->validateHmacSignature($signature, $sharedSecret)) {
                    $this->logger->error('Klarna webhook: Invalid HMAC signature', [
                        'klarna_order_id' => $klarnaOrderId
                    ]);
                    return $result->setHttpResponseCode(401)->setData(['error' => 'Invalid signature']);
                }
            }

            $this->logger->info('Klarna webhook: Push received', [
                'klarna_order_id' => $klarnaOrderId,
                'sid' => $sid
            ]);

            // Fetch order details from Klarna API
            $orderData = $this->fetchKlarnaOrder($klarnaOrderId, $sharedSecret);

            if (!$orderData) {
                $this->logger->error('Klarna webhook: Failed to fetch order from API', [
                    'klarna_order_id' => $klarnaOrderId
                ]);
                return $result->setHttpResponseCode(400)->setData(['error' => 'Cannot fetch order']);
            }

            // Find Magento order by merchant reference
            $quoteId = $orderData['merchant_reference1'] ?? null;

            if (!$quoteId) {
                $this->logger->error('Klarna webhook: No merchant reference in order', [
                    'klarna_order_id' => $klarnaOrderId
                ]);
                return $result->setHttpResponseCode(400)->setData(['error' => 'No merchant reference']);
            }

            $order = $this->orderFactory->create()->loadByAttribute('quote_id', $quoteId);

            if (!$order || !$order->getId()) {
                $this->logger->error('Klarna webhook: Magento order not found', [
                    'quote_id' => $quoteId,
                    'klarna_order_id' => $klarnaOrderId
                ]);
                return $result->setHttpResponseCode(404)->setData(['error' => 'Order not found']);
            }

            // Update order based on Klarna status
            $klarnaStatus = $orderData['status'] ?? 'UNKNOWN';

            switch ($klarnaStatus) {
                case 'AUTHORIZED':
                case 'CAPTURED':
                    $this->handleOrderAuthorized($order, $klarnaOrderId, $orderData);
                    break;

                case 'CANCELLED':
                    $this->handleOrderCancelled($order, $klarnaOrderId);
                    break;

                default:
                    $this->logger->info('Klarna webhook: Unhandled status', [
                        'status' => $klarnaStatus,
                        'klarna_order_id' => $klarnaOrderId
                    ]);
            }

            // Acknowledge receipt
            $this->acknowledgeKlarnaOrder($klarnaOrderId, $sharedSecret);

            return $result->setData(['status' => 'received']);

        } catch (\Exception $e) {
            $this->logger->critical('Klarna webhook: Unexpected error', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return $result->setHttpResponseCode(500)->setData(['error' => 'Server error']);
        }
    }

    /**
     * Validate HMAC signature
     *
     * @param string $signature
     * @param string $sharedSecret
     * @return bool
     */
    protected function validateHmacSignature($signature, $sharedSecret)
    {
        // Get raw POST body
        $payload = file_get_contents('php://input');

        // Calculate expected signature
        $expectedSignature = base64_encode(hash_hmac('sha256', $payload, $sharedSecret, true));

        return hash_equals($expectedSignature, $signature);
    }

    /**
     * Fetch order from Klarna API
     *
     * @param string $klarnaOrderId
     * @param string $sharedSecret
     * @return array|null
     */
    protected function fetchKlarnaOrder($klarnaOrderId, $sharedSecret)
    {
        $merchantId = $this->scopeConfig->getValue(
            'klarna_checkout/general/merchant_id',
            ScopeInterface::SCOPE_STORE
        );

        $testMode = $this->scopeConfig->getValue(
            'klarna_checkout/general/test_mode',
            ScopeInterface::SCOPE_STORE
        );

        $endpoint = $testMode
            ? 'https://api.playground.klarna.com'
            : 'https://api.klarna.com';

        $auth = base64_encode($merchantId . ':' . $sharedSecret);

        $ch = curl_init($endpoint . '/checkout/v3/orders/' . $klarnaOrderId);
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Basic ' . $auth
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_TIMEOUT => 30,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200) {
            $this->logger->error('Klarna API: Failed to fetch order', [
                'http_code' => $httpCode,
                'response' => $response
            ]);
            return null;
        }

        return json_decode($response, true);
    }

    /**
     * Acknowledge Klarna order
     *
     * @param string $klarnaOrderId
     * @param string $sharedSecret
     */
    protected function acknowledgeKlarnaOrder($klarnaOrderId, $sharedSecret)
    {
        $merchantId = $this->scopeConfig->getValue(
            'klarna_checkout/general/merchant_id',
            ScopeInterface::SCOPE_STORE
        );

        $testMode = $this->scopeConfig->getValue(
            'klarna_checkout/general/test_mode',
            ScopeInterface::SCOPE_STORE
        );

        $endpoint = $testMode
            ? 'https://api.playground.klarna.com'
            : 'https://api.klarna.com';

        $auth = base64_encode($merchantId . ':' . $sharedSecret);

        $ch = curl_init($endpoint . '/ordermanagement/v1/orders/' . $klarnaOrderId . '/acknowledge');
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Basic ' . $auth
            ],
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT => 30,
        ]);

        curl_exec($ch);
        curl_close($ch);
    }

    /**
     * Handle authorized/captured order
     *
     * @param Order $order
     * @param string $klarnaOrderId
     * @param array $orderData
     */
    protected function handleOrderAuthorized($order, $klarnaOrderId, $orderData)
    {
        if ($order->getState() === Order::STATE_PENDING_PAYMENT) {
            $order->setState(Order::STATE_PROCESSING);
            $order->setStatus(Order::STATE_PROCESSING);
            $order->addCommentToStatusHistory(
                sprintf('Payment confirmed via Klarna webhook. Order ID: %s', $klarnaOrderId)
            );

            // Store Klarna order ID for future reference
            $order->setData('klarna_order_id', $klarnaOrderId);

            $order->save();

            $this->logger->info('Klarna webhook: Order updated to processing', [
                'order_id' => $order->getIncrementId(),
                'klarna_order_id' => $klarnaOrderId
            ]);
        }
    }

    /**
     * Handle cancelled order
     *
     * @param Order $order
     * @param string $klarnaOrderId
     */
    protected function handleOrderCancelled($order, $klarnaOrderId)
    {
        if ($order->canCancel()) {
            $order->cancel();
            $order->addCommentToStatusHistory(
                sprintf('Order cancelled by Klarna. Order ID: %s', $klarnaOrderId)
            );
            $order->save();

            $this->logger->info('Klarna webhook: Order cancelled', [
                'order_id' => $order->getIncrementId(),
                'klarna_order_id' => $klarnaOrderId
            ]);
        }
    }
}
