<?php
/**
 * Stripe Checkout Module Registration
 */
use Magento\Framework\Component\ComponentRegistrar;

ComponentRegistrar::register(
    ComponentRegistrar::MODULE,
    'Stripe_Checkout',
    __DIR__
);
