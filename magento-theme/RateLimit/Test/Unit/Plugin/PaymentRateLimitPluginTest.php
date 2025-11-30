<?php
namespace Custom\RateLimit\Test\Unit\Plugin;

use Custom\RateLimit\Plugin\PaymentRateLimitPlugin;
use Magento\Framework\App\CacheInterface;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Framework\Exception\LocalizedException;
use Magento\Framework\HTTP\PhpEnvironment\RemoteAddress;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Psr\Log\LoggerInterface;

class PaymentRateLimitPluginTest extends TestCase
{
    /** @var CacheInterface|MockObject */
    private $cache;

    /** @var RemoteAddress|MockObject */
    private $remoteAddress;

    protected function setUp(): void
    {
        $this->cache = $this->createMock(CacheInterface::class);
        $this->remoteAddress = $this->createMock(RemoteAddress::class);
    }

    public function testBeforeExecuteAllowsRequestAndUsesResolvedIp(): void
    {
        $ip = '203.0.113.5';
        $endpoint = DummyController::class;

        $this->remoteAddress->expects($this->once())
            ->method('getRemoteAddress')
            ->willReturn($ip);

        $this->cache->expects($this->exactly(2))
            ->method('load')
            ->willReturnOnConsecutiveCalls(false, false);

        $expectedKey = 'rate_limit_' . md5($ip . '_' . $endpoint);

        $this->cache->expects($this->once())
            ->method('save')
            ->with('1', $expectedKey, [], PaymentRateLimitPlugin::TIME_WINDOW);

        $plugin = $this->createPlugin();

        $result = $plugin->beforeExecute(new DummyController());

        $this->assertNull($result);
    }

    public function testBeforeExecuteLocksOutWhenLimitExceeded(): void
    {
        $ip = '198.51.100.77';
        $this->remoteAddress->method('getRemoteAddress')->willReturn($ip);

        $this->cache->expects($this->exactly(2))
            ->method('load')
            ->willReturnOnConsecutiveCalls(false, PaymentRateLimitPlugin::MAX_REQUESTS);

        $this->cache->expects($this->once())
            ->method('save')
            ->with(
                '1',
                $this->stringContains('rate_limit_lockout_'),
                [],
                PaymentRateLimitPlugin::LOCKOUT_DURATION
            );

        $plugin = $this->createPlugin();

        $this->expectException(LocalizedException::class);
        $plugin->beforeExecute(new DummyController());
    }

    private function createPlugin(): PaymentRateLimitPlugin
    {
        return new PaymentRateLimitPlugin(
            $this->createMock(JsonFactory::class),
            $this->cache,
            $this->createMock(LoggerInterface::class),
            $this->remoteAddress
        );
    }
}

class DummyController
{
}
