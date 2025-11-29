<?php
namespace Stripe\Checkout\Controller\Webhook;

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
 * Stripe Webhook Handler
 *
 * Handles webhook events from Stripe with signature validation
 * Updates order status based on payment events
 */
class Handler extends Action implements HttpPostActionInterface, CsrfAwareActionInterface
{
    /** @var int Maximum age of webhook event in seconds */
    const MAX_EVENT_AGE = 300; // 5 minutes

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
     * Disable CSRF validation for webhooks (Stripe signature provides security)
     *
     * @param RequestInterface $request
     * @return bool|null
     */
    public function validateForCsrf(RequestInterface $request): ?bool
    {
        return true; // Webhook signature validation handles security
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
     * Handle Stripe webhook events
     *
     * @return \Magento\Framework\Controller\Result\Json
     */
    public function execute()
    {
        $result = $this->resultJsonFactory->create();

        try {
            // Get raw POST body
            $payload = file_get_contents('php://input');
            $sigHeader = $this->getRequest()->getHeader('Stripe-Signature');

            if (!$payload || !$sigHeader) {
                $this->logger->warning('Stripe webhook: Missing payload or signature');
                return $result->setHttpResponseCode(400)->setData(['error' => 'Invalid request']);
            }

            // Get webhook secret
            $webhookSecret = $this->scopeConfig->getValue(
                'payment/stripe_checkout/webhook_secret',
                ScopeInterface::SCOPE_STORE
            );

            if (!$webhookSecret) {
                $this->logger->critical('Stripe webhook: Webhook secret not configured');
                return $result->setHttpResponseCode(500)->setData(['error' => 'Configuration error']);
            }

            // Verify webhook signature
            try {
                $event = \Stripe\Webhook::constructEvent(
                    $payload,
                    $sigHeader,
                    $webhookSecret
                );
            } catch (\UnexpectedValueException $e) {
                // Invalid payload
                $this->logger->error('Stripe webhook: Invalid payload', ['error' => $e->getMessage()]);
                return $result->setHttpResponseCode(400)->setData(['error' => 'Invalid payload']);
            } catch (\Stripe\Exception\SignatureVerificationException $e) {
                // Invalid signature
                $this->logger->error('Stripe webhook: Invalid signature', ['error' => $e->getMessage()]);
                return $result->setHttpResponseCode(400)->setData(['error' => 'Invalid signature']);
            }

            // Check event age (replay attack prevention)
            $eventTime = $event->created;
            $currentTime = time();
            if (abs($currentTime - $eventTime) > self::MAX_EVENT_AGE) {
                $this->logger->warning('Stripe webhook: Event too old', [
                    'event_time' => $eventTime,
                    'current_time' => $currentTime
                ]);
                return $result->setHttpResponseCode(400)->setData(['error' => 'Event too old']);
            }

            // Log webhook event
            $this->logger->info('Stripe webhook: Received event', [
                'type' => $event->type,
                'id' => $event->id
            ]);

            // Handle different event types
            switch ($event->type) {
                case 'payment_intent.succeeded':
                    $this->handlePaymentIntentSucceeded($event->data->object);
                    break;

                case 'payment_intent.payment_failed':
                    $this->handlePaymentIntentFailed($event->data->object);
                    break;

                case 'payment_intent.canceled':
                    $this->handlePaymentIntentCanceled($event->data->object);
                    break;

                case 'charge.refunded':
                    $this->handleChargeRefunded($event->data->object);
                    break;

                case 'charge.dispute.created':
                    $this->handleDisputeCreated($event->data->object);
                    break;

                default:
                    $this->logger->info('Stripe webhook: Unhandled event type', ['type' => $event->type]);
            }

            return $result->setData(['received' => true]);

        } catch (\Exception $e) {
            $this->logger->critical('Stripe webhook: Unexpected error', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return $result->setHttpResponseCode(500)->setData(['error' => 'Server error']);
        }
    }

    /**
     * Handle successful payment intent
     *
     * @param \Stripe\PaymentIntent $paymentIntent
     */
    protected function handlePaymentIntentSucceeded($paymentIntent)
    {
        $quoteId = $paymentIntent->metadata->quote_id ?? null;

        if (!$quoteId) {
            $this->logger->warning('Stripe webhook: Missing quote_id in payment_intent.succeeded', [
                'payment_intent_id' => $paymentIntent->id
            ]);
            return;
        }

        // Find order by quote ID
        $order = $this->orderFactory->create()->loadByAttribute('quote_id', $quoteId);

        if (!$order || !$order->getId()) {
            $this->logger->error('Stripe webhook: Order not found', [
                'quote_id' => $quoteId,
                'payment_intent_id' => $paymentIntent->id
            ]);
            return;
        }

        // Update order status
        if ($order->getState() === Order::STATE_PENDING_PAYMENT) {
            $order->setState(Order::STATE_PROCESSING);
            $order->setStatus(Order::STATE_PROCESSING);
            $order->addCommentToStatusHistory(
                sprintf('Payment confirmed via Stripe webhook. Payment Intent: %s', $paymentIntent->id)
            );
            $order->save();

            $this->logger->info('Stripe webhook: Order updated to processing', [
                'order_id' => $order->getIncrementId(),
                'payment_intent_id' => $paymentIntent->id
            ]);
        }
    }

    /**
     * Handle failed payment intent
     *
     * @param \Stripe\PaymentIntent $paymentIntent
     */
    protected function handlePaymentIntentFailed($paymentIntent)
    {
        $quoteId = $paymentIntent->metadata->quote_id ?? null;

        if (!$quoteId) {
            return;
        }

        $order = $this->orderFactory->create()->loadByAttribute('quote_id', $quoteId);

        if ($order && $order->getId()) {
            $order->addCommentToStatusHistory(
                sprintf('Payment failed. Reason: %s. Payment Intent: %s',
                    $paymentIntent->last_payment_error->message ?? 'Unknown',
                    $paymentIntent->id
                )
            );
            $order->save();

            $this->logger->warning('Stripe webhook: Payment failed', [
                'order_id' => $order->getIncrementId(),
                'payment_intent_id' => $paymentIntent->id,
                'error' => $paymentIntent->last_payment_error->message ?? 'Unknown'
            ]);
        }
    }

    /**
     * Handle canceled payment intent
     *
     * @param \Stripe\PaymentIntent $paymentIntent
     */
    protected function handlePaymentIntentCanceled($paymentIntent)
    {
        $quoteId = $paymentIntent->metadata->quote_id ?? null;

        if (!$quoteId) {
            return;
        }

        $order = $this->orderFactory->create()->loadByAttribute('quote_id', $quoteId);

        if ($order && $order->getId() && $order->canCancel()) {
            $order->cancel();
            $order->addCommentToStatusHistory(
                sprintf('Payment canceled. Payment Intent: %s', $paymentIntent->id)
            );
            $order->save();

            $this->logger->info('Stripe webhook: Order canceled', [
                'order_id' => $order->getIncrementId(),
                'payment_intent_id' => $paymentIntent->id
            ]);
        }
    }

    /**
     * Handle charge refund
     *
     * @param \Stripe\Charge $charge
     */
    protected function handleChargeRefunded($charge)
    {
        $paymentIntentId = $charge->payment_intent ?? null;

        if (!$paymentIntentId) {
            return;
        }

        $this->logger->info('Stripe webhook: Charge refunded', [
            'charge_id' => $charge->id,
            'payment_intent_id' => $paymentIntentId,
            'amount_refunded' => $charge->amount_refunded
        ]);

        // Note: Refund handling should be implemented based on business requirements
        // This may involve creating credit memos in Magento
    }

    /**
     * Handle dispute created
     *
     * @param \Stripe\Dispute $dispute
     */
    protected function handleDisputeCreated($dispute)
    {
        $this->logger->critical('Stripe webhook: Dispute created!', [
            'dispute_id' => $dispute->id,
            'charge_id' => $dispute->charge,
            'amount' => $dispute->amount,
            'reason' => $dispute->reason
        ]);

        // Alert administrators about dispute
        // This should trigger email notifications to admin
    }
}
