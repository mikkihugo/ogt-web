<?php
namespace Stripe\Checkout\Controller\Checkout;

use Magento\Framework\App\Action\Action;
use Magento\Framework\App\Action\Context;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Checkout\Model\Session as CheckoutSession;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Store\Model\ScopeInterface;

/**
 * Create Stripe Payment Intent
 */
class CreatePaymentIntent extends Action
{
    protected $resultJsonFactory;
    protected $checkoutSession;
    protected $scopeConfig;

    public function __construct(
        Context $context,
        JsonFactory $resultJsonFactory,
        CheckoutSession $checkoutSession,
        ScopeConfigInterface $scopeConfig
    ) {
        parent::__construct($context);
        $this->resultJsonFactory = $resultJsonFactory;
        $this->checkoutSession = $checkoutSession;
        $this->scopeConfig = $scopeConfig;
    }

    public function execute()
    {
        $result = $this->resultJsonFactory->create();

        try {
            // Get quote (cart) from session
            $quote = $this->checkoutSession->getQuote();
            
            if (!$quote->getId()) {
                return $result->setData([
                    'success' => false,
                    'error' => 'No active cart found'
                ]);
            }

            // Get Stripe API key
            $testMode = $this->scopeConfig->getValue(
                'payment/stripe_checkout/test_mode',
                ScopeInterface::SCOPE_STORE
            );
            
            $apiKey = $testMode 
                ? $this->scopeConfig->getValue('payment/stripe_checkout/test_secret_key', ScopeInterface::SCOPE_STORE)
                : $this->scopeConfig->getValue('payment/stripe_checkout/live_secret_key', ScopeInterface::SCOPE_STORE);

            if (!$apiKey) {
                return $result->setData([
                    'success' => false,
                    'error' => 'Stripe not configured'
                ]);
            }

            \Stripe\Stripe::setApiKey($apiKey);

            // Create Payment Intent
            $amount = (int)($quote->getGrandTotal() * 100); // Convert to cents
            $currency = strtolower($quote->getQuoteCurrencyCode());

            $paymentIntent = \Stripe\PaymentIntent::create([
                'amount' => $amount,
                'currency' => $currency,
                'metadata' => [
                    'quote_id' => $quote->getId(),
                    'store_name' => 'OrgasmToy.com'
                ],
                'description' => 'Order from OrgasmToy.com'
            ]);

            return $result->setData([
                'success' => true,
                'client_secret' => $paymentIntent->client_secret,
                'payment_intent_id' => $paymentIntent->id
            ]);

        } catch (\Exception $e) {
            return $result->setData([
                'success' => false,
                'error' => $e->getMessage()
            ]);
        }
    }
}
