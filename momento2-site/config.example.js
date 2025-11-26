/**
 * Configuration Example for momento2 site
 * 
 * Copy this file to config.js and update with your actual keys
 * Add config.js to .gitignore to keep secrets out of version control
 */

// Set Stripe publishable key
// Get from: https://dashboard.stripe.com/apikeys
window.STRIPE_KEY = 'pk_test_YOUR_PUBLISHABLE_KEY_HERE';

// For production, use live key:
// window.STRIPE_KEY = 'pk_live_YOUR_LIVE_KEY_HERE';

/**
 * Include this in your HTML before checkout.js:
 * <script src="config.js"></script>
 * <script src="js/checkout.js"></script>
 */
