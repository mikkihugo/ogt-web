<?php
namespace Stripe\Checkout\Controller\Checkout;

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
use Magento\Store\Model\ScopeInterface;
use Psr\Log\LoggerInterface;

/**
 * Create Stripe Payment Intent
 *
 * Securely creates a Stripe Payment Intent for checkout
 * Implements CSRF protection and comprehensive validation
 */
class CreatePaymentIntent extends Action implements HttpPostActionInterface, CsrfAwareActionInterface
{
    /** @var int Minimum allowed payment amount in cents */
    const MIN_AMOUNT_CENTS = 50; // $0.50 USD minimum

    /** @var int Maximum allowed payment amount in cents */
    const MAX_AMOUNT_CENTS = 100000000; // $1,000,000 USD maximum

    /** @var int Convert dollars to cents */
    const CENTS_MULTIPLIER = 100;

    /** @var array Supported currencies */
    const SUPPORTED_CURRENCIES = ['usd', 'eur', 'gbp', 'cad', 'aud'];

    protected $resultJsonFactory;
    protected $checkoutSession;
    protected $scopeConfig;
    protected $formKeyValidator;
    protected $logger;

    public function __construct(
        Context $context,
        JsonFactory $resultJsonFactory,
        CheckoutSession $checkoutSession,
        ScopeConfigInterface $scopeConfig,
        FormKeyValidator $formKeyValidator,
        LoggerInterface $logger
    ) {
        parent::__construct($context);
        $this->resultJsonFactory = $resultJsonFactory;
        $this->checkoutSession = $checkoutSession;
        $this->scopeConfig = $scopeConfig;
        $this->formKeyValidator = $formKeyValidator;
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
     * Execute payment intent creation with comprehensive validation
     *
     * @return \Magento\Framework\Controller\Result\Json
     */
    public function execute()
    {
        $result = $this->resultJsonFactory->create();

        try {
            // Validate request method
            if (!$this->getRequest()->isPost()) {
                $this->logger->warning('Stripe: Non-POST request attempted');
                return $result->setData([
                    'success' => false,
                    'error' => __('Invalid request method')
                ]);
            }

            // Get quote (cart) from session
            $quote = $this->checkoutSession->getQuote();

            if (!$quote->getId() || !$quote->getItemsCount()) {
                $this->logger->info('Stripe: Payment intent creation attempted with empty cart');
                return $result->setData([
                    'success' => false,
                    'error' => __('Your cart is empty. Please add items before checkout.')
                ]);
            }

            // Validate amount
            $amount = (int)($quote->getGrandTotal() * self::CENTS_MULTIPLIER);
            if ($amount < self::MIN_AMOUNT_CENTS) {
                $this->logger->warning('Stripe: Amount too small', ['amount' => $amount, 'quote_id' => $quote->getId()]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Order amount is too small')
                ]);
            }

            if ($amount > self::MAX_AMOUNT_CENTS) {
                $this->logger->warning('Stripe: Amount too large', ['amount' => $amount, 'quote_id' => $quote->getId()]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Order amount exceeds maximum allowed')
                ]);
            }

            // Validate currency
            $currency = strtolower($quote->getQuoteCurrencyCode());
            if (!in_array($currency, self::SUPPORTED_CURRENCIES)) {
                $this->logger->error('Stripe: Unsupported currency', ['currency' => $currency, 'quote_id' => $quote->getId()]);
                return $result->setData([
                    'success' => false,
                    'error' => __('Currency not supported')
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
                $this->logger->critical('Stripe: API key not configured');
                return $result->setData([
                    'success' => false,
                    'error' => __('Payment method not available. Please contact support.')
                ]);
            }

            \Stripe\Stripe::setApiKey($apiKey);

            // Create Payment Intent with enhanced metadata
            $paymentIntent = \Stripe\PaymentIntent::create([
                'amount' => $amount,
                'currency' => $currency,
                'metadata' => [
                    'quote_id' => $quote->getId(),
                    'customer_email' => $quote->getCustomerEmail() ?: 'guest',
                    'store_name' => 'OrgasmToy.com',
                    'items_count' => $quote->getItemsCount()
                ],
                'description' => sprintf('Order #%s from OrgasmToy.com', $quote->getId()),
                'statement_descriptor' => 'ORGASMTOY.COM', // Discreet billing descriptor
                'automatic_payment_methods' => [
                    'enabled' => true,
                ],
            ]);

            // Log successful creation
            $this->logger->info('Stripe: Payment intent created', [
                'payment_intent_id' => $paymentIntent->id,
                'quote_id' => $quote->getId(),
                'amount' => $amount,
                'currency' => $currency
            ]);

            return $result->setData([
                'success' => true,
                'client_secret' => $paymentIntent->client_secret,
                'payment_intent_id' => $paymentIntent->id
            ]);

        } catch (\Stripe\Exception\ApiErrorException $e) {
            // Log Stripe-specific errors with full context
            $this->logger->error('Stripe API error: ' . $e->getMessage(), [
                'error_type' => get_class($e),
                'quote_id' => $quote->getId() ?? 'unknown',
                'trace' => $e->getTraceAsString()
            ]);

            return $result->setData([
                'success' => false,
                'error' => __('Payment processing error. Please try again or contact support.')
            ]);

        } catch (\Exception $e) {
            // Log unexpected errors with full details
            $this->logger->critical('Stripe: Unexpected error in payment intent creation', [
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
}
