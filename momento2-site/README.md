# Momento2 Site - Production Frontend

Production-ready e-commerce frontend for orgasmtoy.com with shopping cart and checkout.

## Features

- Responsive mobile-first design
- Shopping cart with localStorage persistence
- Dual payment options (Stripe & Klarna)
- Product catalog with 6 featured items
- Secure checkout with XSS prevention

## Configuration

### 1. Stripe Integration

Create `config.js` from the example:

```bash
cp config.example.js config.js
```

Edit `config.js` and add your Stripe publishable key:

```javascript
window.STRIPE_KEY = 'pk_test_YOUR_KEY';
```

Include it in your HTML before the checkout script:

```html
<script src="config.js"></script>
<script src="js/checkout.js"></script>
```

**Never commit config.js** - it's in .gitignore

### 2. Product Images

Currently using placeholder images from via.placeholder.com.

For production:
1. Add real product images to `images/products/`
2. Update image URLs in `index.html`
3. Or integrate with Magento catalog

### 3. Shipping Configuration

Shipping cost is hardcoded to $9.99 in `checkout.js` line 45.

For production:
- Calculate dynamically based on location
- Integrate with shipping API (USPS, UPS, FedEx)
- Or fetch from Magento shipping configuration

## Development

Start local server:

```bash
python3 -m http.server 8000
```

Visit http://localhost:8000

## Production Deployment

This site is deployed via the main Dockerfile to Fly.io.

For Magento integration, these files serve as the frontend templates.

## Security

- All user inputs are sanitized
- XSS prevention implemented
- No inline event handlers with user data
- API keys loaded from configuration
- HTTPS enforced

## File Structure

```
momento2-site/
├── index.html          # Homepage with product catalog
├── checkout.html       # Checkout page
├── config.example.js   # Configuration template
├── css/
│   └── style.css       # Complete site styling
└── js/
    ├── cart.js         # Shopping cart logic
    ├── checkout.js     # Payment processing
    └── main.js         # Site interactions
```

## Integration with Magento

To use with full Magento:

1. Copy payment modules from `magento-theme/` to Magento
2. Install and configure Stripe_Checkout and Klarna_Checkout
3. Use these HTML/CSS/JS as templates for your Magento theme
4. Replace API endpoints to use Magento routes

## Support

See main repository README for full documentation.
