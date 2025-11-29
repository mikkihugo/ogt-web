<?php
/**
 * Rate Limiting Module Registration
 *
 * Provides rate limiting for payment endpoints to prevent brute force attacks
 */
\Magento\Framework\Component\ComponentRegistrar::register(
    \Magento\Framework\Component\ComponentRegistrar::MODULE,
    'Custom_RateLimit',
    __DIR__
);
