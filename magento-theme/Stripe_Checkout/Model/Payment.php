<?php
namespace Stripe\Checkout\Model;

use Magento\Payment\Model\Method\AbstractMethod;
use Magento\Framework\Exception\LocalizedException;

/**
 * Stripe Payment Method Model
 */
class Payment extends AbstractMethod
{
    const CODE = 'stripe_checkout';

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
     * Authorize payment
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
            
            if ($paymentIntentId) {
                $intent = \Stripe\PaymentIntent::retrieve($paymentIntentId);
                
                // Store transaction ID
                $payment->setTransactionId($intent->id);
                $payment->setIsTransactionClosed(false);
            }
        } catch (\Exception $e) {
            $this->_logger->error('Stripe authorization error: ' . $e->getMessage());
            throw new LocalizedException(__('Payment authorization failed. Please try again or contact support.'));
        }

        return $this;
    }

    /**
     * Capture payment
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
            
            if ($paymentIntentId) {
                $intent = \Stripe\PaymentIntent::retrieve($paymentIntentId);
                
                if ($intent->status === 'requires_capture') {
                    $intent->capture();
                }
                
                $payment->setTransactionId($intent->id);
                $payment->setIsTransactionClosed(true);
            }
        } catch (\Exception $e) {
            $this->_logger->error('Stripe capture error: ' . $e->getMessage());
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
