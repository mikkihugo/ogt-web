<?php
namespace Klarna_Checkout\Test\Unit\Controller\Webhook;

use Klarna_Checkout\Controller\Webhook\Push;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Framework\App\RequestInterface;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Sales\Model\Order;
use Magento\Sales\Model\OrderFactory;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Psr\Log\LoggerInterface;

class PushTest extends TestCase
{
    public function testExecuteReturns401WhenSignatureMissing(): void
    {
        $controller = $this->getMockBuilder(Push::class)
            ->disableOriginalConstructor()
            ->onlyMethods(['getRequest'])
            ->getMock();

        $resultJson = new FakeJsonResult();

        $request = $this->createMock(RequestInterface::class);
        $request->method('getParam')->willReturnMap([
            ['klarna_order_id', null, 'order-123'],
            ['sid', null, 'sid-1']
        ]);
        $request->method('getHeader')->willReturnMap([
            ['Klarna-Signature', null, null]
        ]);

        $this->setProperty($controller, 'resultJsonFactory', $this->mockJsonFactory($resultJson));
        $this->setProperty($controller, 'scopeConfig', $this->mockScopeConfig());
        $this->setProperty($controller, 'orderFactory', $this->createMock(OrderFactory::class));
        $this->setProperty($controller, 'logger', $this->createMock(LoggerInterface::class));

        $controller->method('getRequest')->willReturn($request);

        $response = $controller->execute();

        $this->assertSame(401, $response->code);
        $this->assertSame(['error' => 'Missing signature'], $response->data);
    }

    public function testExecuteReturns401WhenSignatureInvalid(): void
    {
        $controller = $this->getMockBuilder(Push::class)
            ->disableOriginalConstructor()
            ->onlyMethods([
                'getRequest',
                'validateHmacSignature'
            ])
            ->getMock();

        $resultJson = new FakeJsonResult();

        $request = $this->createMock(RequestInterface::class);
        $request->method('getParam')->willReturnMap([
            ['klarna_order_id', null, 'order-123'],
            ['sid', null, 'sid-1']
        ]);
        $request->method('getHeader')->willReturnMap([
            ['Klarna-Signature', null, 'bad-sig']
        ]);

        $controller->method('getRequest')->willReturn($request);
        $controller->method('validateHmacSignature')->willReturn(false);

        $this->setProperty($controller, 'resultJsonFactory', $this->mockJsonFactory($resultJson));
        $this->setProperty($controller, 'scopeConfig', $this->mockScopeConfig());
        $this->setProperty($controller, 'orderFactory', $this->createMock(OrderFactory::class));
        $this->setProperty($controller, 'logger', $this->createMock(LoggerInterface::class));

        $response = $controller->execute();

        $this->assertSame(401, $response->code);
        $this->assertSame(['error' => 'Invalid signature'], $response->data);
    }

    public function testExecuteReturns400WhenFetchFails(): void
    {
        $controller = $this->getMockBuilder(Push::class)
            ->disableOriginalConstructor()
            ->onlyMethods([
                'getRequest',
                'validateHmacSignature',
                'fetchKlarnaOrder'
            ])
            ->getMock();

        $resultJson = new FakeJsonResult();

        $request = $this->createMock(RequestInterface::class);
        $request->method('getParam')->willReturnMap([
            ['klarna_order_id', null, 'order-123'],
            ['sid', null, 'sid-1']
        ]);
        $request->method('getHeader')->willReturnMap([
            ['Klarna-Signature', null, 'valid-sig']
        ]);

        $controller->method('getRequest')->willReturn($request);
        $controller->method('validateHmacSignature')->willReturn(true);
        $controller->method('fetchKlarnaOrder')->willReturn(null);

        $this->setProperty($controller, 'resultJsonFactory', $this->mockJsonFactory($resultJson));
        $this->setProperty($controller, 'scopeConfig', $this->mockScopeConfig());
        $this->setProperty($controller, 'orderFactory', $this->createMock(OrderFactory::class));
        $this->setProperty($controller, 'logger', $this->createMock(LoggerInterface::class));

        $response = $controller->execute();

        $this->assertSame(400, $response->code);
        $this->assertSame(['error' => 'Cannot fetch order'], $response->data);
    }

    public function testExecuteReturns502WhenAcknowledgementFails(): void
    {
        $controller = $this->getMockBuilder(Push::class)
            ->disableOriginalConstructor()
            ->onlyMethods([
                'getRequest',
                'fetchKlarnaOrder',
                'acknowledgeKlarnaOrder',
                'handleOrderAuthorized',
                'handleOrderCancelled',
                'validateHmacSignature'
            ])
            ->getMock();

        $resultJson = new FakeJsonResult();

        $request = $this->createMock(RequestInterface::class);
        $request->method('getParam')->willReturnMap([
            ['klarna_order_id', null, 'order-123'],
            ['sid', null, 'sid-1']
        ]);
        $request->method('getHeader')->willReturnMap([
            ['Klarna-Signature', null, 'valid-sig']
        ]);

        $scopeConfig = $this->mockScopeConfig();

        $order = $this->createMock(Order::class);
        $order->method('loadByAttribute')->willReturnSelf();
        $order->method('getId')->willReturn(10);

        $orderFactory = $this->createMock(OrderFactory::class);
        $orderFactory->method('create')->willReturn($order);

        $controller->method('getRequest')->willReturn($request);
        $controller->method('fetchKlarnaOrder')->willReturn([
            'merchant_reference1' => '42',
            'status' => 'AUTHORIZED'
        ]);
        $controller->method('acknowledgeKlarnaOrder')->willReturn(['success' => false, 'http_code' => 500]);
        $controller->method('validateHmacSignature')->willReturn(true);

        $this->setProperty($controller, 'resultJsonFactory', $this->mockJsonFactory($resultJson));
        $this->setProperty($controller, 'scopeConfig', $scopeConfig);
        $this->setProperty($controller, 'orderFactory', $orderFactory);
        $this->setProperty($controller, 'logger', $this->createMock(LoggerInterface::class));

        $response = $controller->execute();

        $this->assertSame(502, $response->code);
        $this->assertSame(['error' => 'Acknowledgement failed'], $response->data);
    }

    public function testExecuteReturnsReceivedOnSuccess(): void
    {
        $controller = $this->getMockBuilder(Push::class)
            ->disableOriginalConstructor()
            ->onlyMethods([
                'getRequest',
                'fetchKlarnaOrder',
                'acknowledgeKlarnaOrder',
                'handleOrderAuthorized',
                'handleOrderCancelled',
                'validateHmacSignature'
            ])
            ->getMock();

        $resultJson = new FakeJsonResult();

        $request = $this->createMock(RequestInterface::class);
        $request->method('getParam')->willReturnMap([
            ['klarna_order_id', null, 'order-123'],
            ['sid', null, 'sid-1']
        ]);
        $request->method('getHeader')->willReturnMap([
            ['Klarna-Signature', null, 'valid-sig']
        ]);

        $scopeConfig = $this->mockScopeConfig();

        $order = $this->createMock(Order::class);
        $order->method('loadByAttribute')->willReturnSelf();
        $order->method('getId')->willReturn(10);

        $orderFactory = $this->createMock(OrderFactory::class);
        $orderFactory->method('create')->willReturn($order);

        $controller->method('getRequest')->willReturn($request);
        $controller->method('fetchKlarnaOrder')->willReturn([
            'merchant_reference1' => '42',
            'status' => 'AUTHORIZED'
        ]);
        $controller->method('acknowledgeKlarnaOrder')->willReturn(['success' => true]);
        $controller->method('validateHmacSignature')->willReturn(true);

        $this->setProperty($controller, 'resultJsonFactory', $this->mockJsonFactory($resultJson));
        $this->setProperty($controller, 'scopeConfig', $scopeConfig);
        $this->setProperty($controller, 'orderFactory', $orderFactory);
        $this->setProperty($controller, 'logger', $this->createMock(LoggerInterface::class));

        $response = $controller->execute();

        $this->assertSame(200, $response->code);
        $this->assertSame(['status' => 'received'], $response->data);
    }

    private function mockJsonFactory(FakeJsonResult $result): JsonFactory
    {
        $factory = $this->createMock(JsonFactory::class);
        $factory->method('create')->willReturn($result);

        return $factory;
    }

    private function mockScopeConfig(): ScopeConfigInterface
    {
        $scopeConfig = $this->createMock(ScopeConfigInterface::class);
        $scopeConfig->method('getValue')->willReturnMap([
            ['klarna_checkout/general/shared_secret', 'store', null, 'secret'],
            ['klarna_checkout/general/test_mode', 'store', null, false],
            ['klarna_checkout/general/merchant_id', 'store', null, 'merchant']
        ]);

        return $scopeConfig;
    }

    private function setProperty(object $object, string $property, $value): void
    {
        $ref = new \ReflectionProperty($object, $property);
        $ref->setAccessible(true);
        $ref->setValue($object, $value);
    }
}

class FakeJsonResult
{
    public $data;
    public $code = 200;

    public function setData(array $data)
    {
        $this->data = $data;
        return $this;
    }

    public function setHttpResponseCode($code)
    {
        $this->code = $code;
        return $this;
    }
}
