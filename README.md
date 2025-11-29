# orgasmtoy E-commerce Platform

A complete e-commerce solution built with Adobe Magento (open source), featuring Stripe and Klarna payment integration, optimized for deployment on Fly.io.

## 🚀 What's Included

This repository contains everything needed to launch **orgasmtoy.com**:

- **momento2-site/** — Production-ready static site for orgasmtoy.com with shopping cart, Stripe & Klarna checkout
- **magento-theme/** — Complete Magento 2 modules for full e-commerce functionality
  - `Stripe_Checkout/` — Full Stripe payment gateway integration
  - `Klarna_Checkout/` — Complete Klarna payment integration
- **Fly.io deployment** — Containerized deployment with auto-scaling
- **CI/CD** — Automatic deployment from Git
- **Runtime stack** — Hyperconverged container (Caddy + PHP-FPM over unix socket, MariaDB socket-only, Redis, Prometheus exporters), built and reproducible via Nix with git-crypt-managed secrets

## 🎯 Quick Start

### Try the orgasmtoy site locally

The site is production-ready with shopping cart and checkout:

```bash
cd momento2-site
python3 -m http.server 8000
# Open http://localhost:8000 in your browser
```

Features:
- Full shopping cart with localStorage persistence
- Product catalog with 6 featured items
- Stripe payment integration (frontend)
- Klarna payment option
- Responsive mobile-first design

### Try legacy prototype

```bash
cd theme-prototype
python3 -m http.server 8001
# Open http://localhost:8001 in your browser
```

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

## 💳 Payment Integration

### Stripe Module (`magento-theme/Stripe_Checkout/`)

Full-featured Stripe payment gateway for Magento 2:
- Complete Stripe API integration using stripe-php library
- Payment Intent creation with automatic capture
- Test and live mode support
- Secure credential storage
- Void and refund capabilities

Copy to Magento: `app/code/Stripe/Checkout`

See [Stripe_Checkout/README.md](magento-theme/Stripe_Checkout/README.md) for setup instructions.

### Klarna Module (`magento-theme/Klarna_Checkout/`)

Full Klarna Checkout integration with real API calls:
- Klarna Checkout API v3 integration
- Order line items with tax calculation
- Test (playground) and production modes
- Webhook support for payment confirmation
- Configured for orgasmtoy.com domain

Copy to Magento: `app/code/Klarna/Checkout`

See [Klarna_Checkout/README.md](magento-theme/Klarna_Checkout/README.md) for setup instructions.

## 🚢 Deploy to Fly.io (Production)

Deploy orgasmtoy.com to Fly.io with one command:

```bash
# Install Fly.io CLI
curl -L https://fly.io/install.sh | sh

# Authenticate
fly auth login

# Deploy
fly deploy
```

The site will be live at your Fly.io URL. To use orgasmtoy.com:

```bash
fly certs add orgasmtoy.com
# Follow DNS instructions
```

**Automatic Deployment**: Push to `main` branch triggers auto-deploy via GitHub Actions.

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment guide including:
- Custom domain setup for orgasmtoy.com
- Environment secrets configuration
- Database setup
- Full Magento deployment
- Monitoring and scaling

## 📦 Repository Structure

```
magneto-web/
├── momento2-site/          # Production site for orgasmtoy.com
│   ├── index.html          # Homepage with product catalog
│   ├── checkout.html       # Checkout with Stripe & Klarna
│   ├── css/style.css       # Complete styling
│   └── js/
│       ├── cart.js         # Shopping cart management
│       ├── checkout.js     # Payment processing
│       └── main.js         # Site functionality
├── magento-theme/          # Magento 2 modules
│   ├── Stripe_Checkout/   # Full Stripe integration
│   ├── Klarna_Checkout/   # Full Klarna integration
│   ├── composer.json       # Theme metadata
│   └── theme.xml           # Theme configuration
├── theme-prototype/        # Legacy prototype
├── Dockerfile             # Production container
├── fly.toml               # Fly.io configuration
├── DEPLOYMENT.md          # Complete deployment guide
└── .github/workflows/     # CI/CD automation
```

## 🔒 Security & Best Practices

- ✅ Encrypted payment credentials
- ✅ HTTPS/SSL enforced
- ✅ No secrets in code
- ✅ Test mode for development
- ✅ Production-ready error handling
- ✅ PCI DSS compliant payment flow

## 🔒 Secrets & Key Management (Nix-native, CI, Fly.io)
- Secrets (e.g. `.env.encrypted`, `secrets/*`) are encrypted in the repo using git-crypt.
- The git-crypt key is named `../.keys/ogt-web.git-crypt.key` and should never be committed.
- Backup/restore the key via a private Gist using `./gitcrypt-gist.sh`.
- Inject secrets into Fly.io or GitHub Actions using `./secrets-sync.sh fly .env.encrypted` or `./secrets-sync.sh gh .env.encrypted`.
- All scripts are available in the Nix dev shell and referenced in `flake.nix`.

## 🛠️ Technology Stack

- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **E-commerce**: Adobe Magento 2 (Open Source)
- **Payments**: Stripe API v3, Klarna Checkout API v3
- **Deployment**: Fly.io (containerized)
- **CI/CD**: GitHub Actions
- **Database**: MySQL/MariaDB (for Magento)

## 📚 Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Complete deployment guide
- [Stripe_Checkout/README.md](magento-theme/Stripe_Checkout/README.md) - Stripe module docs
- [Klarna_Checkout/README.md](magento-theme/Klarna_Checkout/README.md) - Klarna module docs

## 🤝 Contributing

Contributions are welcome! Please open issues or pull requests with improvements.

## 📄 License

This project is licensed under the MIT License.
