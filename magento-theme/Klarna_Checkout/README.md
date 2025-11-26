# Klarna Checkout starter module

This is a small starter skeleton for integrating Klarna Checkout into a Magento 2 store. It is intentionally minimal — it provides:

- Admin configuration fields for merchant ID and shared secret
- A frontend controller stub `klarna/checkout/createsession` which returns a test session payload

How to use
1. Copy this folder into your Magento 2 instance under `app/code/Klarna/Checkout`.
2. Run `php bin/magento setup:upgrade` and `php bin/magento cache:flush`.
3. In Admin → Stores → Configuration → Sales → Klarna Checkout, set Merchant ID and Shared Secret (test credentials from Klarna).
4. Implement the real Klarna API calls in `Controller/Checkout/CreateSession.php` (there's a commented note where to replace the stub).

Domain and Klarna account notes
- Your domain: orgasmtoy.com — register this in Klarna's merchant portal for allowed origins and return URLs.
- Klarna requires you to request test/sandbox credentials through their Merchant Portal. Use Klarna's documentation for correct endpoints and webhooks.

Security & testing
- Never check live secrets into source control. Use environment variables and Magento's encrypted config entries where possible.
- Test thoroughly in Klarna sandbox mode before flipping to production.
