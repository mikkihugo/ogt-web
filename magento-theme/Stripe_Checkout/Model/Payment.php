<?php
namespace Stripe\Checkout\Model;

use Magento\Payment\Model\Method\AbstractMethod;
use Magento\Framework\Exception\LocalizedException;

/**
 * Stripe Payment Method Model
 *
 * Implements secure payment processing with amount verification
 * to prevent payment manipulation attacks
 */
class Payment extends AbstractMethod
{
    const CODE = 'stripe_checkout';
    const CENTS_MULTIPLIER = 100;

    protected $_code = self::CODE;
    protected $_isGateway = true;
    protected $_canAuthorize = true;
    protected $_canCapture = true;
    protected $_canVoid = true;
    protected $_canUseCheckout = true;

    /**
     * @var \Magento\Framework\App\Config\ScopeConfigInterface
     */
    protected $scopeConfig;

    public function __construct(
        \Magento\Framework\Model\Context $context,
        \Magento\Framework\Registry $registry,
        \Magento\Framework\Api\ExtensionAttributesFactory $extensionFactory,
        \Magento\Framework\Api\AttributeValueFactory $customAttributeFactory,
        \Magento\Payment\Helper\Data $paymentData,
        \Magento\Framework\App\Config\ScopeConfigInterface $scopeConfig,
        \Magento\Payment\Model\Method\Logger $logger,
        \Magento\Framework\Model\ResourceModel\AbstractResource $resource = null,
        \Magento\Framework\Data\Collection\AbstractDb $resourceCollection = null,
        array $data = []
    ) {
        parent::__construct(
            $context,
            $registry,
            $extensionFactory,
            $customAttributeFactory,
            $paymentData,
            $scopeConfig,
            $logger,
            $resource,
            $resourceCollection,
            $data
        );
        $this->scopeConfig = $scopeConfig;
    }

    /**
     * Get Stripe API Key
     */
    protected function getApiKey()
    {
        $testMode = $this->getConfigData('test_mode');
        $key = $testMode 
            ? $this->getConfigData('test_secret_key')
            : $this->getConfigData('live_secret_key');
        
        return $key;
    }

    /**
     * Authorize payment with amount verification
     *
     * @param \Magento\Payment\Model\InfoInterface $payment
     * @param float $amount
     * @return $this
     * @throws LocalizedException
     */
    public function authorize(\Magento\Payment\Model\InfoInterface $payment, $amount)
    {
        if (!$this->canAuthorize()) {
            throw new LocalizedException(__('The authorize action is not available.'));
        }

        // Set up Stripe API
        $apiKey = $this->getApiKey();
        if (!$apiKey) {
            throw new LocalizedException(__('Stripe API key not configured.'));
        }

        \Stripe\Stripe::setApiKey($apiKey);

        try {
            // Get payment intent from additional information
            $paymentIntentId = $payment->getAdditionalInformation('payment_intent_id');

            if (!$paymentIntentId) {
                $this->_logger->error('Stripe: Missing payment intent ID during authorization');
                throw new LocalizedException(__('Payment intent not found. Please try again.'));
            }

            // Retrieve payment intent from Stripe
            $intent = \Stripe\PaymentIntent::retrieve($paymentIntentId);

            // CRITICAL: Verify payment intent amount matches order amount
            $expectedAmountCents = (int)($amount * self::CENTS_MULTIPLIER);
            $actualAmountCents = $intent->amount;

            if ($expectedAmountCents !== $actualAmountCents) {
                $this->_logger->critical('Stripe: Payment amount mismatch detected!', [
                    'payment_intent_id' => $paymentIntentId,
                    'expected_cents' => $expectedAmountCents,
                    'actual_cents' => $actualAmountCents,
                    'order_id' => $payment->getOrder()->getIncrementId()
                ]);

                throw new LocalizedException(__(
                    'Payment amount verification failed. Expected %1, got %2. Transaction cancelled for security.',
                    $amount,
                    $actualAmountCents / self::CENTS_MULTIPLIER
                ));
            }

            // Verify payment intent currency matches order currency
            $expectedCurrency = strtolower($payment->getOrder()->getOrderCurrencyCode());
            $actualCurrency = strtolower($intent->currency);

            if ($expectedCurrency !== $actualCurrency) {
                $this->_logger->critical('Stripe: Currency mismatch detected!', [
                    'payment_intent_id' => $paymentIntentId,
                    'expected_currency' => $expectedCurrency,
                    'actual_currency' => $actualCurrency
                ]);

                throw new LocalizedException(__('Payment currency mismatch. Transaction cancelled.'));
            }

            // Verify payment intent status
            if (!in_array($intent->status, ['requires_capture', 'succeeded'])) {
                $this->_logger->warning('Stripe: Invalid payment intent status for authorization', [
                    'status' => $intent->status,
                    'payment_intent_id' => $paymentIntentId
                ]);

                throw new LocalizedException(__('Payment cannot be authorized. Status: %1', $intent->status));
            }

            // Store transaction ID and metadata
            $payment->setTransactionId($intent->id);
            $payment->setIsTransactionClosed(false);
            $payment->setAdditionalInformation('stripe_amount_verified', true);
            $payment->setAdditionalInformation('stripe_status', $intent->status);

            $this->_logger->info('Stripe: Authorization successful', [
                'payment_intent_id' => $intent->id,
                'amount' => $amount,
                'order_id' => $payment->getOrder()->getIncrementId()
            ]);

        } catch (LocalizedException $e) {
            throw $e;
        } catch (\Exception $e) {
            $this->_logger->error('Stripe authorization error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString()
            ]);
            throw new LocalizedException(__('Payment authorization failed. Please try again or contact support.'));
        }

        return $this;
    }

    /**
     * Capture payment with amount verification
     *
     * @param \Magento\Payment\Model\InfoInterface $payment
     * @param float $amount
     * @return $this
     * @throws LocalizedException
     */
    public function capture(\Magento\Payment\Model\InfoInterface $payment, $amount)
    {
        if (!$this->canCapture()) {
            throw new LocalizedException(__('The capture action is not available.'));
        }

        $apiKey = $this->getApiKey();
        if (!$apiKey) {
            throw new LocalizedException(__('Stripe API key not configured.'));
        }

        \Stripe\Stripe::setApiKey($apiKey);

        try {
            $paymentIntentId = $payment->getAdditionalInformation('payment_intent_id');

            if (!$paymentIntentId) {
                $this->_logger->error('Stripe: Missing payment intent ID during capture');
                throw new LocalizedException(__('Payment intent not found. Cannot capture payment.'));
            }

            // Retrieve payment intent from Stripe
            $intent = \Stripe\PaymentIntent::retrieve($paymentIntentId);

            // CRITICAL: Verify payment intent amount matches capture amount
            $expectedAmountCents = (int)($amount * self::CENTS_MULTIPLIER);
            $actualAmountCents = $intent->amount;

            if ($expectedAmountCents !== $actualAmountCents) {
                $this->_logger->critical('Stripe: Capture amount mismatch detected!', [
                    'payment_intent_id' => $paymentIntentId,
                    'expected_cents' => $expectedAmountCents,
                    'actual_cents' => $actualAmountCents,
                    'order_id' => $payment->getOrder()->getIncrementId()
                ]);

                throw new LocalizedException(__(
                    'Capture amount verification failed. Expected %1, got %2. Capture cancelled.',
                    $amount,
                    $actualAmountCents / self::CENTS_MULTIPLIER
                ));
            }

            // Verify currency matches
            $expectedCurrency = strtolower($payment->getOrder()->getOrderCurrencyCode());
            $actualCurrency = strtolower($intent->currency);

            if ($expectedCurrency !== $actualCurrency) {
                $this->_logger->critical('Stripe: Capture currency mismatch!', [
                    'payment_intent_id' => $paymentIntentId,
                    'expected' => $expectedCurrency,
                    'actual' => $actualCurrency
                ]);

                throw new LocalizedException(__('Currency mismatch. Capture cancelled.'));
            }

            // Capture if status requires it
            if ($intent->status === 'requires_capture') {
                $this->_logger->info('Stripe: Capturing payment', [
                    'payment_intent_id' => $paymentIntentId,
                    'amount' => $amount
                ]);

                $intent->capture();

                // Verify capture was successful
                $intent = \Stripe\PaymentIntent::retrieve($paymentIntentId);

                if ($intent->status !== 'succeeded') {
                    $this->_logger->error('Stripe: Capture failed', [
                        'status' => $intent->status,
                        'payment_intent_id' => $paymentIntentId
                    ]);

                    throw new LocalizedException(__('Payment capture failed. Status: %1', $intent->status));
                }
            } elseif ($intent->status === 'succeeded') {
                // Already captured (auto-capture enabled)
                $this->_logger->info('Stripe: Payment already captured', [
                    'payment_intent_id' => $paymentIntentId
                ]);
            } else {
                $this->_logger->error('Stripe: Invalid status for capture', [
                    'status' => $intent->status,
                    'payment_intent_id' => $paymentIntentId
                ]);

                throw new LocalizedException(__('Cannot capture payment. Status: %1', $intent->status));
            }

            $payment->setTransactionId($intent->id);
            $payment->setIsTransactionClosed(true);
            $payment->setAdditionalInformation('stripe_captured', true);

            $this->_logger->info('Stripe: Capture successful', [
                'payment_intent_id' => $intent->id,
                'amount' => $amount,
                'order_id' => $payment->getOrder()->getIncrementId()
            ]);

        } catch (LocalizedException $e) {
            throw $e;
        } catch (\Exception $e) {
            $this->_logger->error('Stripe capture error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString()
            ]);
            throw new LocalizedException(__('Payment capture failed. Please contact support.'));
        }

        return $this;
    }

    /**
     * Void payment
     */
    public function void(\Magento\Payment\Model\InfoInterface $payment)
    {
        if (!$this->canVoid()) {
            throw new LocalizedException(__('The void action is not available.'));
        }

        $apiKey = $this->getApiKey();
        \Stripe\Stripe::setApiKey($apiKey);

        try {
            $paymentIntentId = $payment->getAdditionalInformation('payment_intent_id');
            
            if ($paymentIntentId) {
                $intent = \Stripe\PaymentIntent::retrieve($paymentIntentId);
                $intent->cancel();
            }
        } catch (\Exception $e) {
            $this->_logger->error('Stripe void error: ' . $e->getMessage());
            throw new LocalizedException(__('Payment void failed. Please contact support.'));
        }

        return $this;
    }
}
