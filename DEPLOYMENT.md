# Deployment Guide for Momento2 (orgasmtoy.com)

This guide covers deploying the momento2 e-commerce site to Fly.io with Adobe Magento integration.

## Overview

The repository contains:
1. **momento2-site/** - Production-ready static site with Stripe/Klarna checkout
2. **magento-theme/** - Magento 2 modules for full e-commerce functionality
3. **Fly.io configuration** - For cloud deployment

## Quick Deploy to Fly.io

### Prerequisites

1. Install Fly.io CLI:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. Sign up and authenticate:
   ```bash
   fly auth signup
   # or
   fly auth login
   ```

### Deploy Steps

1. **Initialize Fly app** (first time only):
   ```bash
   fly launch --name momento2-orgasmtoy --region iad
   ```
   Choose "No" when asked to deploy now.

2. **Set environment secrets**:
   ```bash
   # Stripe keys
   fly secrets set STRIPE_PUBLISHABLE_KEY=pk_live_...
   fly secrets set STRIPE_SECRET_KEY=sk_live_...
   
   # Klarna credentials
   fly secrets set KLARNA_MERCHANT_ID=your_merchant_id
   fly secrets set KLARNA_SHARED_SECRET=your_shared_secret
   ```

3. **Deploy**:
   ```bash
   fly deploy
   ```

4. **Open your site**:
   ```bash
   fly open
   ```

### Custom Domain Setup (orgasmtoy.com)

1. **Add domain to Fly.io**:
   ```bash
   fly certs add orgasmtoy.com
   fly certs add www.orgasmtoy.com
   ```

2. **Configure DNS** (at your domain registrar):
   ```
   A     orgasmtoy.com          → [Fly.io IP from `fly ips list`]
   AAAA  orgasmtoy.com          → [Fly.io IPv6 from `fly ips list`]
   CNAME www.orgasmtoy.com      → orgasmtoy.com
   ```

3. **Verify SSL**:
   ```bash
   fly certs check orgasmtoy.com
   ```

## Automated Deployment from Git

The repository includes GitHub Actions workflow for automatic deployment:

1. **Get Fly.io API token**:
   ```bash
   fly auth token
   ```

2. **Add to GitHub Secrets**:
   - Go to repository Settings → Secrets → Actions
   - Add secret: `FLY_API_TOKEN` with your token

3. **Push to main branch**:
   ```bash
   git push origin main
   ```
   The site will automatically deploy!

## Full Magento Deployment

For a complete Magento 2 installation:

### Option 1: Fly.io with External Database

1. **Create Fly Postgres**:
   ```bash
   fly postgres create --name momento2-db
   fly postgres attach momento2-db -a momento2-orgasmtoy
   ```

2. **Update Dockerfile** to install full Magento

3. **Deploy with volumes**:
   ```bash
   fly volumes create momento2_media --region iad --size 10
   fly deploy
   ```

### Option 2: Traditional Hosting

1. **Install Magento 2**:
   ```bash
   composer create-project --repository-url=https://repo.magento.com/ \
     magento/project-community-edition magento2
   ```

2. **Copy modules**:
   ```bash
   cp -r magento-theme/Stripe_Checkout magento2/app/code/Stripe/Checkout
   cp -r magento-theme/Klarna_Checkout magento2/app/code/Klarna/Checkout
   ```

3. **Install**:
   ```bash
   cd magento2
   php bin/magento setup:install \
     --base-url=https://orgasmtoy.com \
     --db-host=localhost \
     --db-name=magento \
     --db-user=magento \
     --db-password=password \
     --admin-firstname=Admin \
     --admin-lastname=User \
     --admin-email=admin@orgasmtoy.com \
     --admin-user=admin \
     --admin-password=Admin123! \
     --language=en_US \
     --currency=USD \
     --timezone=America/New_York \
     --use-rewrites=1
   ```

4. **Enable modules**:
   ```bash
   php bin/magento module:enable Stripe_Checkout Klarna_Checkout
   php bin/magento setup:upgrade
   php bin/magento setup:di:compile
   php bin/magento setup:static-content:deploy -f
   php bin/magento cache:flush
   ```

## Payment Gateway Configuration

### Stripe Setup

1. Get API keys from https://dashboard.stripe.com/apikeys
2. In Magento Admin:
   - Stores → Configuration → Sales → Payment Methods
   - Expand "Stripe Payment Gateway"
   - Enable and configure with your keys

### Klarna Setup

1. Register at https://www.klarna.com/us/business/
2. Register domain: orgasmtoy.com
3. Get credentials from Klarna Merchant Portal
4. In Magento Admin:
   - Stores → Configuration → Sales → Klarna Checkout
   - Configure with your merchant ID and secret

## Monitoring

```bash
# View logs
fly logs

# Check app status
fly status

# Scale resources
fly scale memory 512
fly scale count 2
```

## Rollback

```bash
# List releases
fly releases

# Rollback to previous
fly releases rollback
```

## Security Checklist

- [ ] SSL/HTTPS enabled (automatic with Fly.io)
- [ ] Payment keys stored in secrets (not in code)
- [ ] Test mode disabled in production
- [ ] Webhook URLs configured
- [ ] Admin panel secured
- [ ] Regular backups configured
- [ ] Firewall rules in place
- [ ] Rate limiting enabled

## Support

- Fly.io Docs: https://fly.io/docs
- Magento Docs: https://devdocs.magento.com
- Stripe Docs: https://stripe.com/docs
- Klarna Docs: https://docs.klarna.com
