<?php
namespace Klarna_Checkout\Controller\Checkout;

use Magento\Framework\App\Action\Action;
use Magento\Framework\App\Action\Context;
use Magento\Framework\Controller\Result\JsonFactory;

class CreateSession extends Action
{
    private $resultJsonFactory;

    public function __construct(Context $context, JsonFactory $resultJsonFactory)
    {
        parent::__construct($context);
        $this->resultJsonFactory = $resultJsonFactory;
    }

    public function execute()
    {
        $result = $this->resultJsonFactory->create();

        // NOTE: This is a stub. Replace with real Klarna API calls using your merchant credentials.
        $session = [
            'client_token' => 'TEST_CLIENT_TOKEN',
            'session_id' => 'TEST_SESSION_'.time(),
            'redirect_url' => 'https://checkout.klarna.com/example'
        ];

        return $result->setData(['success' => true, 'session' => $session]);
    }
}
