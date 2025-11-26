<?php
namespace Klarna_Checkout\Controller\Checkout;

use Magento\Framework\App\Action\Action;
use Magento\Framework\App\Action\Context;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Checkout\Model\Session as CheckoutSession;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Store\Model\ScopeInterface;

class CreateSession extends Action
{
    private $resultJsonFactory;
    private $checkoutSession;
    private $scopeConfig;

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
                return $result->setData([
                    'success' => false,
                    'error' => 'Klarna not configured'
                ]);
            }

            // Set Klarna API endpoint
            $endpoint = $testMode 
                ? 'https://api.playground.klarna.com'
                : 'https://api.klarna.com';

            // Prepare order data
            $orderAmount = (int)($quote->getGrandTotal() * 100); // Convert to cents
            $currency = $quote->getQuoteCurrencyCode();

            $orderData = [
                'purchase_country' => 'US',
                'purchase_currency' => $currency,
                'locale' => 'en-US',
                'order_amount' => $orderAmount,
                'order_tax_amount' => (int)($quote->getShippingAddress()->getTaxAmount() * 100),
                'order_lines' => $this->getOrderLines($quote),
                'merchant_urls' => [
                    'terms' => 'https://orgasmtoy.com/terms',
                    'checkout' => 'https://orgasmtoy.com/checkout',
                    'confirmation' => 'https://orgasmtoy.com/checkout/success',
                    'push' => 'https://orgasmtoy.com/klarna/checkout/push'
                ]
            ];

            // Make API call to Klarna
            $auth = base64_encode($merchantId . ':' . $sharedSecret);
            
            $ch = curl_init($endpoint . '/checkout/v3/orders');
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Authorization: Basic ' . $auth
            ]);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($orderData));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($httpCode !== 201) {
                return $result->setData([
                    'success' => false,
                    'error' => 'Failed to create Klarna session'
                ]);
            }

            $sessionData = json_decode($response, true);

            return $result->setData([
                'success' => true,
                'session' => [
                    'order_id' => $sessionData['order_id'],
                    'html_snippet' => $sessionData['html_snippet'],
                    'session_id' => $sessionData['session_id'] ?? null
                ]
            ]);

        } catch (\Exception $e) {
            return $result->setData([
                'success' => false,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Convert quote items to Klarna order lines
     */
    private function getOrderLines($quote)
    {
        $lines = [];
        
        foreach ($quote->getAllVisibleItems() as $item) {
            $lines[] = [
                'type' => 'physical',
                'reference' => $item->getSku(),
                'name' => $item->getName(),
                'quantity' => (int)$item->getQty(),
                'unit_price' => (int)($item->getPrice() * 100),
                'tax_rate' => (int)($item->getTaxPercent() * 100),
                'total_amount' => (int)($item->getRowTotal() * 100),
                'total_tax_amount' => (int)($item->getTaxAmount() * 100)
            ];
        }
        
        // Add shipping
        if ($quote->getShippingAddress()->getShippingAmount() > 0) {
            $lines[] = [
                'type' => 'shipping_fee',
                'reference' => 'SHIPPING',
                'name' => $quote->getShippingAddress()->getShippingDescription(),
                'quantity' => 1,
                'unit_price' => (int)($quote->getShippingAddress()->getShippingAmount() * 100),
                'tax_rate' => 0,
                'total_amount' => (int)($quote->getShippingAddress()->getShippingAmount() * 100),
                'total_tax_amount' => 0
            ];
        }
        
        return $lines;
    }
}
