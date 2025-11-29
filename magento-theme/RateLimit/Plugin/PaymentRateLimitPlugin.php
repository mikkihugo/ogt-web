<?php
namespace Custom\RateLimit\Plugin;

use Magento\Framework\App\RequestInterface;
use Magento\Framework\Controller\Result\JsonFactory;
use Magento\Framework\App\CacheInterface;
use Psr\Log\LoggerInterface;

/**
 * Payment Rate Limiting Plugin
 *
 * Prevents brute force attacks on payment endpoints by limiting requests per IP
 * Uses Redis cache for high-performance distributed rate limiting
 */
class PaymentRateLimitPlugin
{
    /** @var int Maximum requests allowed per time window */
    const MAX_REQUESTS = 10;

    /** @var int Time window in seconds (5 minutes) */
    const TIME_WINDOW = 300;

    /** @var int Lockout duration in seconds after exceeding limit (15 minutes) */
    const LOCKOUT_DURATION = 900;

    /** @var RequestInterface */
    protected $request;

    /** @var JsonFactory */
    protected $resultJsonFactory;

    /** @var CacheInterface */
    protected $cache;

    /** @var LoggerInterface */
    protected $logger;

    public function __construct(
        RequestInterface $request,
        JsonFactory $resultJsonFactory,
        CacheInterface $cache,
        LoggerInterface $logger
    ) {
        $this->request = $request;
        $this->resultJsonFactory = $resultJsonFactory;
        $this->cache = $cache;
        $this->logger = $logger;
    }

    /**
     * Before plugin to check rate limit before action execution
     *
     * @param mixed $subject
     * @return array|null
     */
    public function beforeExecute($subject)
    {
        $clientIp = $this->getClientIp();
        $endpoint = $this->getEndpointIdentifier($subject);

        // Check if IP is currently locked out
        if ($this->isLockedOut($clientIp, $endpoint)) {
            $this->logger->warning('Rate limit exceeded - IP locked out', [
                'ip' => $clientIp,
                'endpoint' => $endpoint
            ]);

            throw new \Magento\Framework\Exception\LocalizedException(
                __('Too many requests. Please try again in 15 minutes.')
            );
        }

        // Check and increment request count
        if (!$this->checkRateLimit($clientIp, $endpoint)) {
            // Lock out the IP
            $this->lockoutIp($clientIp, $endpoint);

            $this->logger->warning('Rate limit exceeded - IP now locked out', [
                'ip' => $clientIp,
                'endpoint' => $endpoint,
                'lockout_duration' => self::LOCKOUT_DURATION
            ]);

            throw new \Magento\Framework\Exception\LocalizedException(
                __('Too many requests. Please try again in 15 minutes.')
            );
        }

        // Allow request to proceed
        return null;
    }

    /**
     * Get client IP address (supports proxies)
     *
     * @return string
     */
    protected function getClientIp(): string
    {
        // Check for IP behind proxy
        $headers = [
            'HTTP_X_FORWARDED_FOR',
            'HTTP_X_REAL_IP',
            'HTTP_CLIENT_IP',
            'REMOTE_ADDR'
        ];

        foreach ($headers as $header) {
            $ip = $this->request->getServer($header);
            if ($ip && filter_var($ip, FILTER_VALIDATE_IP)) {
                // If X-Forwarded-For contains multiple IPs, take the first one
                if (strpos($ip, ',') !== false) {
                    $ips = explode(',', $ip);
                    $ip = trim($ips[0]);
                }
                return $ip;
            }
        }

        return '0.0.0.0';
    }

    /**
     * Get endpoint identifier from controller
     *
     * @param mixed $subject
     * @return string
     */
    protected function getEndpointIdentifier($subject): string
    {
        return get_class($subject);
    }

    /**
     * Check if IP is currently locked out
     *
     * @param string $ip
     * @param string $endpoint
     * @return bool
     */
    protected function isLockedOut(string $ip, string $endpoint): bool
    {
        $lockoutKey = $this->getLockoutKey($ip, $endpoint);
        $lockoutData = $this->cache->load($lockoutKey);

        return $lockoutData !== false;
    }

    /**
     * Check rate limit and increment counter
     *
     * @param string $ip
     * @param string $endpoint
     * @return bool True if within limit, false if exceeded
     */
    protected function checkRateLimit(string $ip, string $endpoint): bool
    {
        $cacheKey = $this->getRateLimitKey($ip, $endpoint);
        $requestCount = $this->cache->load($cacheKey);

        if ($requestCount === false) {
            // First request in window
            $this->cache->save('1', $cacheKey, [], self::TIME_WINDOW);
            return true;
        }

        $requestCount = (int)$requestCount;

        if ($requestCount >= self::MAX_REQUESTS) {
            // Rate limit exceeded
            return false;
        }

        // Increment counter
        $this->cache->save((string)($requestCount + 1), $cacheKey, [], self::TIME_WINDOW);
        return true;
    }

    /**
     * Lock out IP address
     *
     * @param string $ip
     * @param string $endpoint
     */
    protected function lockoutIp(string $ip, string $endpoint): void
    {
        $lockoutKey = $this->getLockoutKey($ip, $endpoint);
        $this->cache->save('1', $lockoutKey, [], self::LOCKOUT_DURATION);
    }

    /**
     * Get rate limit cache key
     *
     * @param string $ip
     * @param string $endpoint
     * @return string
     */
    protected function getRateLimitKey(string $ip, string $endpoint): string
    {
        return 'rate_limit_' . md5($ip . '_' . $endpoint);
    }

    /**
     * Get lockout cache key
     *
     * @param string $ip
     * @param string $endpoint
     * @return string
     */
    protected function getLockoutKey(string $ip, string $endpoint): string
    {
        return 'rate_limit_lockout_' . md5($ip . '_' . $endpoint);
    }
}
