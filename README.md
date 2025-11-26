# Magneto Webstore

An open-source e-commerce webstore built with [Magento](https://magento.com/).

This repository now includes two helpful starting points for building a tasteful, sensual storefront:

- `theme-prototype/` — a static, Lelo-like prototype site (HTML + CSS) you can open locally to preview a refined layout and product pages.
- `magento-theme/` — a minimal Magento 2 theme skeleton (registration, theme.xml, composer.json) to copy into a Magento 2 instance and adapt templates and assets.

## Try the prototype locally

The prototype is purely static and can be opened directly in a browser, or served with a simple HTTP server.

From the project root you can run (Python 3):

```bash
cd theme-prototype
python3 -m http.server 8000
# then open http://localhost:8000 in your browser
```

This will let you preview the Lelo-like layout, product cards and modal interactions.

## Install Magento 2 locally with Docker (optional)

If you want to install a local Magento 2 using Docker to test the theme integration, there's a simple Docker Compose setup and helper script included.

1. Copy `.env.example` to `.env` and fill in your Magento repo credentials (get them from https://repo.magento.com/).

```bash
cp .env.example .env
# edit .env, set COMPOSER_MAGENTO_USERNAME and COMPOSER_MAGENTO_PASSWORD
```

2. Start the Docker services and install Magento (this will build images and run composer inside the PHP container):

```bash
# make the script executable first
chmod +x magento-install.sh
./magento-install.sh
```

The installer script will:
- start MariaDB, Redis, Elasticsearch, PHP-FPM and Nginx via Docker Compose
- configure composer auth (repo.magento.com) inside the PHP container
- run `composer create-project` to download Magento
- run `bin/magento setup:install` with reasonable defaults

After the install completes you should be able to visit the base URL set in `.env` (default http://localhost:8080/).

Notes:
- You still need to copy the `magento-theme/` folder into `app/design/frontend/<Vendor>/msgnet2` inside the Magento project to apply the theme.
- This script is a convenience for development and testing; for production follow Magento's official deployment guides.

## Using the Magento 2 theme skeleton

The `magento-theme/` folder is a minimal starting point. To install into a Magento 2 project:

1. Copy the folder into your Magento 2 codebase under `app/design/frontend/<Vendor>/msgnet2`.
2. Add your static assets under `web/css`, `web/images`, and move or create template files under `Magento_Theme/templates`, `Magento_Catalog/templates`, etc., mapping layout XML as needed.
3. From your Magento root run:

```bash
php bin/magento setup:upgrade
php bin/magento setup:static-content:deploy -f
php bin/magento cache:flush
```

4. In the Admin panel go to Content → Design → Configuration and set the new theme for your store view.

## Recommended premade starting themes and resources

If you want a more complete starting point instead of building from scratch, consider these Magento 2 themes and starter kits (commercial/open-source):

- Porto (ThemeForest) — mature, lots of e-commerce features and demos.
- Ultimo — classic responsive theme with many layout options.
- Hyva (modern frontend) — modern, fast front-end stack for Magento 2.
- Blank/Blank Luma — Magento's own starter themes (good for learning and extending).

When choosing a theme for adult products, prefer themes that are:

- Discreet and tasteful in imagery and content flows.
- Mobile-first responsive and accessible.
- Easy to customize templates and CSS variables.

## Contributing

Contributions are welcome! Please open issues or pull requests with improvements to the prototype or the Magento skeleton.

## Klarna Checkout starter module

There is a starter Klarna module in `magento-theme/Klarna_Checkout/` with admin settings and a controller stub. Copy it into your Magento app under `app/code/Klarna/Checkout` and extend the controller to use real Klarna API calls. The module README contains notes about registering your domain (orgasmtoy.com) and getting test credentials.

## License

This project is licensed under the MIT License.