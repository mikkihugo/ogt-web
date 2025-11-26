# msgnet2 Magento 2 theme skeleton

This folder contains a minimal Magento 2 theme skeleton you can use to start integrating the prototype UI into Magento 2 (Luma-like folder structure). It is not a full theme — copy templates, layout XML and styles into your Magento 2 installation under app/design/frontend/Vendor/msgnet2.

Files included:
- `registration.php` — Magento theme registration
- `theme.xml` — basic theme metadata
- `composer.json` — optional composer package

Next steps:
1. Copy this folder to your Magento 2 instance at `app/design/frontend/<Vendor>/msgnet2`.
2. Add static assets under `web/css`, `web/images`, etc., and map templates.
3. Run bin/magento setup:upgrade and deploy static content as needed.
