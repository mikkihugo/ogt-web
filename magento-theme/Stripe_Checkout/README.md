# Stripe Checkout Module for Magento 2

This module integrates Stripe payment gateway with Magento 2 for orgasmtoy.com.

## Installation

1. Copy this folder to your Magento 2 instance:
   ```bash
   cp -r Stripe_Checkout app/code/Stripe/Checkout
   ```

2. Install Stripe PHP library:
   ```bash
   composer require stripe/stripe-php
   ```

3. Enable the module:
   ```bash
   php bin/magento module:enable Stripe_Checkout
   php bin/magento setup:upgrade
   php bin/magento setup:di:compile
   php bin/magento cache:flush
   ```

## Configuration

1. Log in to Magento Admin Panel
2. Navigate to: **Stores → Configuration → Sales → Payment Methods**
3. Expand **Stripe Payment Gateway** section
4. Configure the following:
   - **Enabled**: Yes
   - **Title**: Credit Card (Stripe)
   - **Test Mode**: Yes (for testing) / No (for production)
   - **Test/Live Keys**: Enter your Stripe API keys

## Getting Stripe API Keys

1. Sign up at https://stripe.com
2. Go to https://dashboard.stripe.com/apikeys
3. Copy your **Publishable key** and **Secret key**
4. For testing, use test mode keys (they start with `pk_test_` and `sk_test_`)
5. For production on orgasmtoy.com, use live keys (start with `pk_live_` and `sk_live_`)

## Usage

Once configured, customers will see "Credit Card (Stripe)" as a payment option during checkout.

## Frontend Integration

To use Stripe in your theme, include Stripe.js:

```html
<script src="https://js.stripe.com/v3/"></script>
```

Then initialize with your publishable key:

```javascript
const stripe = Stripe('YOUR_PUBLISHABLE_KEY');
```

## API Endpoints

- `POST /stripe/checkout/createpaymentintent` - Creates a payment intent for the current cart

## Security Notes

- Never commit API keys to version control
- Always use encrypted config fields in Magento
- Test thoroughly in sandbox mode before going live
- Use webhooks for payment confirmations in production

## Support

For issues or questions, contact the development team or visit https://stripe.com/docs
