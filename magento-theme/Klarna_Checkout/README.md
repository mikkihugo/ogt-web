# Klarna Checkout Module for Magento 2

Full Klarna Checkout integration for Magento 2 - orgasmtoy.com

## Features

- Complete Klarna API integration
- Admin configuration for test and live credentials
- Frontend checkout session creation
- Order line items and tax calculation
- Webhook support for payment confirmation

## Installation

1. Copy this folder into your Magento 2 instance:
   ```bash
   cp -r Klarna_Checkout app/code/Klarna/Checkout
   ```

2. Enable the module:
   ```bash
   php bin/magento module:enable Klarna_Checkout
   php bin/magento setup:upgrade
   php bin/magento setup:di:compile
   php bin/magento cache:flush
   ```

## Configuration

1. Log in to Magento Admin Panel
2. Navigate to: **Stores → Configuration → Sales → Klarna Checkout**
3. Configure:
   - **Merchant ID**: Your Klarna merchant ID
   - **Shared Secret**: Your Klarna shared secret
   - **Test Mode**: Yes (for testing) / No (for production)

## Getting Klarna Credentials

1. Sign up for Klarna merchant account: https://www.klarna.com/us/business/
2. Access Klarna Merchant Portal
3. Register domain: **orgasmtoy.com**
4. Get test credentials for sandbox environment
5. Get production credentials after approval

### Important URLs for orgasmtoy.com

Register these URLs in Klarna Merchant Portal:
- Terms: https://orgasmtoy.com/terms
- Checkout: https://orgasmtoy.com/checkout
- Confirmation: https://orgasmtoy.com/checkout/success
- Push (webhook): https://orgasmtoy.com/klarna/checkout/push

## API Endpoints

- `POST /klarna/checkout/createsession` - Creates Klarna checkout session

## Implementation Details

The module now includes:
- Real Klarna API v3 integration
- Order line items with tax calculation
- Support for physical products and shipping
- Proper error handling
- Currency and locale support

## Testing

1. Use Klarna Playground environment
2. Endpoint: `https://api.playground.klarna.com`
3. Test with Klarna's test payment methods
4. Verify webhook integration

## Production Checklist

- [ ] Register orgasmtoy.com with Klarna
- [ ] Get production credentials
- [ ] Set Test Mode to No
- [ ] Configure live Merchant ID and Secret
- [ ] Test payment flow end-to-end
- [ ] Configure webhooks
- [ ] Enable SSL/HTTPS

## Security Notes

- Never commit live credentials to version control
- Use Magento's encrypted config fields
- Implement webhook signature validation
- Test thoroughly in sandbox before going live

## Support

- Klarna API Docs: https://docs.klarna.com
- Magento Documentation: https://devdocs.magento.com
