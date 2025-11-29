<?php
namespace Klarna_Checkout\Controller\Checkout;

use Magento\Framework\App\Action\Action;
use Magento\Framework\App\Action\Context;
use Magento\Framework\App\Action\HttpPostActionInterface;
use Magento\Framework\App\CsrfAwareActionInterface;
use Magento\Framework\App\Request\InvalidRequestException;
use Magento\Framework\App\RequestInterface;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Checkout\Model\Session as CheckoutSession;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Framework\Data\Form\FormKey\Validator as FormKeyValidator;
use Magento\Framework\UrlInterface;
use Magento\Store\Model\ScopeInterface;
use Psr\Log\LoggerInterface;

/**
 * Create Klarna Checkout Session
 *
 * Securely creates a Klarna Checkout session for payment processing
 * Implements CSRF protection and comprehensive validation
 */
class CreateSession extends Action implements HttpPostActionInterface, CsrfAwareActionInterface
{
    /** @var int Minimum allowed payment amount in cents */
    const MIN_AMOUNT_CENTS = 50;

    /** @var int Maximum allowed payment amount in cents */
    const MAX_AMOUNT_CENTS = 100000000;

    /** @var int Convert dollars to cents */
    const CENTS_MULTIPLIER = 100;

    /** @var int cURL timeout in seconds */
    const CURL_TIMEOUT = 30;

    /** @var array Supported currencies for Klarna */
    const SUPPORTED_CURRENCIES = ['USD', 'EUR', 'GBP', 'SEK', 'NOK', 'DKK'];

    /** @var array Supported countries for Klarna */
    const SUPPORTED_COUNTRIES = ['US', 'GB', 'DE', 'SE', 'NO', 'DK', 'FI'];

    private $resultJsonFactory;
    private $checkoutSession;
    private $scopeConfig;
    private $formKeyValidator;
    private $urlBuilder;
    private $logger;

    public function __construct(
        Context $context,
        JsonFactory $resultJsonFactory,
        CheckoutSession $checkoutSession,
        ScopeConfigInterface $scopeConfig,
        FormKeyValidator $formKeyValidator,
        UrlInterface $urlBuilder,
        LoggerInterface $logger
    ) {
        parent::__construct($context);
        $this->resultJsonFactory = $resultJsonFactory;
        $this->checkoutSession = $checkoutSession;
        $this->scopeConfig = $scopeConfig;
        $this->formKeyValidator = $formKeyValidator;
        $this->urlBuilder = $urlBuilder;
        $this->logger = $logger;
    }

    /**
     * Create exception for CSRF validation failure
     *
     * @param RequestInterface $request
     * @return InvalidRequestException|null
     */
    public function createCsrfValidationException(RequestInterface $request): ?InvalidRequestException
    {
        return new InvalidRequestException(
            __('Invalid security token. Please refresh the page and try again.')
        );
    }

    /**
     * Validate CSRF token for this action
     *
     * @param RequestInterface $request
     * @return bool|null
     */
    public function validateForCsrf(RequestInterface $request): ?bool
    {
        return $this->formKeyValidator->validate($request);
    }

    /**
     * Execute Klarna session creation with comprehensive validation
     *
     * @return \Magento\Framework\Controller\Result\Json
     */
    public function execute()
    {
        $result = $this->resultJsonFactory->create();

        try {
            // Validate request method
            if (!$this->getRequest()->isPost()) {
                $this->logger->warning('Klarna: Non-POST request attempted');
                return $result->setData([
                    'success' => false,
                    'error' => __('Invalid request method')
                ]);
            }

            // Get quote (cart) from session
            $quote = $this->checkoutSession->getQuote();

            if (!$quote->getId() || !$quote->getItemsCount()) {
                $this->logger->info('Klarna: Session creation attempted with empty cart');
                return $result->setData([
                    'success' => false,
                    'error' => __('Your cart is empty. Please add items before checkout.')
                ]);
            }

            // Validate amount
            $orderAmount = (int)($quote->getGrandTotal() * self::CENTS_MULTIPLIER);
            if ($orderAmount < self::MIN_AMOUNT_CENTS) {
                $this->logger->warning('Klarna: Amount too small', ['amount' => $orderAmount, 'quote_id' => $quote->getId()]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Order amount is too small')
                ]);
            }

            if ($orderAmount > self::MAX_AMOUNT_CENTS) {
                $this->logger->warning('Klarna: Amount too large', ['amount' => $orderAmount, 'quote_id' => $quote->getId()]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Order amount exceeds maximum allowed')
                ]);
            }

            // Validate currency
            $currency = strtoupper($quote->getQuoteCurrencyCode());
            if (!in_array($currency, self::SUPPORTED_CURRENCIES)) {
                $this->logger->error('Klarna: Unsupported currency', ['currency' => $currency, 'quote_id' => $quote->getId()]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Currency not supported for Klarna payments')
                ]);
            }

            // Get Klarna credentials
            $merchantId = $this->scopeConfig->getValue(
                'klarna_checkout/general/merchant_id',
                ScopeInterface::SCOPE_STORE
            );

            $sharedSecret = $this->scopeConfig->getValue(
                'klarna_checkout/general/shared_secret',
                ScopeInterface::SCOPE_STORE
            );

            $testMode = $this->scopeConfig->getValue(
                'klarna_checkout/general/test_mode',
                ScopeInterface::SCOPE_STORE
            );

            if (!$merchantId || !$sharedSecret) {
                $this->logger->critical('Klarna: Credentials not configured');
                return $result->setData([
                    'success' => false,
                    'error' => __('Payment method not available. Please contact support.')
                ]);
            }

            // Set Klarna API endpoint
            $endpoint = $testMode
                ? 'https://api.playground.klarna.com'
                : 'https://api.klarna.com';

            // Build merchant URLs using base URL from config
            $baseUrl = $this->urlBuilder->getBaseUrl();
            $merchantUrls = [
                'terms' => $baseUrl . 'terms',
                'checkout' => $baseUrl . 'checkout',
                'confirmation' => $baseUrl . 'checkout/success',
                'push' => $baseUrl . 'klarna/checkout/push'
            ];

            // Prepare order data
            $orderData = [
                'purchase_country' => 'US', // TODO: Get from shipping address
                'purchase_currency' => $currency,
                'locale' => 'en-US',
                'order_amount' => $orderAmount,
                'order_tax_amount' => (int)(($quote->getShippingAddress()->getTaxAmount() ?? 0) * self::CENTS_MULTIPLIER),
                'order_lines' => $this->getOrderLines($quote),
                'merchant_urls' => $merchantUrls,
                'merchant_reference1' => (string)$quote->getId(),
                'merchant_reference2' => 'OrgasmToy Order',
            ];

            // Make API call to Klarna with proper error handling
            $response = $this->makeKlarnaApiCall($endpoint, $merchantId, $sharedSecret, $orderData, $quote->getId());

            if (!$response['success']) {
                return $result->setData([
                    'success' => false,
                    'error' => __('Unable to initialize payment session. Please try again.')
                ]);
            }

            $sessionData = $response['data'];

            // Validate response structure
            if (!isset($sessionData['order_id']) || !isset($sessionData['html_snippet'])) {
                $this->logger->error('Klarna: Invalid response structure', ['response' => $sessionData]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Payment session error. Please try again.')
                ]);
            }

            // Log successful creation
            $this->logger->info('Klarna: Session created', [
                'order_id' => $sessionData['order_id'],
                'quote_id' => $quote->getId(),
                'amount' => $orderAmount,
                'currency' => $currency
            ]);

            return $result->setData([
                'success' => true,
                'session' => [
                    'order_id' => $sessionData['order_id'],
                    'html_snippet' => $sessionData['html_snippet'],
                    'session_id' => $sessionData['session_id'] ?? null
                ]
            ]);

        } catch (\Exception $e) {
            // Log unexpected errors with full details
            $this->logger->critical('Klarna: Unexpected error in session creation', [
                'error' => $e->getMessage(),
                'quote_id' => $quote->getId() ?? 'unknown',
                'trace' => $e->getTraceAsString()
            ]);

            return $result->setData([
                'success' => false,
                'error' => __('An unexpected error occurred. Please try again or contact support.')
            ]);
        }
    }

    /**
     * Make API call to Klarna with proper error handling and timeout
     *
     * @param string $endpoint
     * @param string $merchantId
     * @param string $sharedSecret
     * @param array $orderData
     * @param int $quoteId
     * @return array
     */
    private function makeKlarnaApiCall($endpoint, $merchantId, $sharedSecret, $orderData, $quoteId)
    {
        $auth = base64_encode($merchantId . ':' . $sharedSecret);

        $ch = curl_init($endpoint . '/checkout/v3/orders');
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Basic ' . $auth
            ],
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($orderData),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_TIMEOUT => self::CURL_TIMEOUT,
            CURLOPT_CONNECTTIMEOUT => 10,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($curlError) {
            $this->logger->error('Klarna: cURL error', [
                'error' => $curlError,
                'quote_id' => $quoteId
            ]);
            return ['success' => false];
        }

        if ($httpCode !== 201) {
            $this->logger->error('Klarna: API error', [
                'http_code' => $httpCode,
                'response' => $response,
                'quote_id' => $quoteId
            ]);
            return ['success' => false];
        }

        $sessionData = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            $this->logger->error('Klarna: Invalid JSON response', [
                'json_error' => json_last_error_msg(),
                'quote_id' => $quoteId
            ]);
            return ['success' => false];
        }

        return [
            'success' => true,
            'data' => $sessionData
        ];
    }

    /**
     * Convert quote items to Klarna order lines with validation
     *
     * @param \Magento\Quote\Model\Quote $quote
     * @return array
     */
    private function getOrderLines($quote)
    {
        $lines = [];

        foreach ($quote->getAllVisibleItems() as $item) {
            $lines[] = [
                'type' => 'physical',
                'reference' => substr($item->getSku() ?? 'unknown', 0, 64), // Klarna max 64 chars
                'name' => substr($item->getName() ?? 'Product', 0, 255), // Klarna max 255 chars
                'quantity' => max(1, (int)$item->getQty()),
                'unit_price' => (int)($item->getPrice() * self::CENTS_MULTIPLIER),
                'tax_rate' => (int)(($item->getTaxPercent() ?? 0) * self::CENTS_MULTIPLIER),
                'total_amount' => (int)($item->getRowTotal() * self::CENTS_MULTIPLIER),
                'total_tax_amount' => (int)(($item->getTaxAmount() ?? 0) * self::CENTS_MULTIPLIER)
            ];
        }

        // Add shipping if present
        $shippingAmount = $quote->getShippingAddress()->getShippingAmount();
        if ($shippingAmount && $shippingAmount > 0) {
            $lines[] = [
                'type' => 'shipping_fee',
                'reference' => 'SHIPPING',
                'name' => $quote->getShippingAddress()->getShippingDescription() ?? 'Shipping',
                'quantity' => 1,
                'unit_price' => (int)($shippingAmount * self::CENTS_MULTIPLIER),
                'tax_rate' => 0,
                'total_amount' => (int)($shippingAmount * self::CENTS_MULTIPLIER),
                'total_tax_amount' => 0
            ];
        }

        return $lines;
    }
}
