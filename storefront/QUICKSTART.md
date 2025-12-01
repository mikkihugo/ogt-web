# Quick Start Guide

## Setup (5 minutes)

1. **Install dependencies**:
   ```bash
   cd /home/nixos/code/ogt-web/storefront
   yarn install
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   ```

   Edit `.env` and ensure it has:
   ```
   PUBLIC_MEDUSA_BACKEND_URL=https://api.orgasmtoy.com
   ```

3. **Start development server**:
   ```bash
   yarn dev
   ```

   Visit: http://localhost:4321

## What's Been Built

A complete Medusa v2 storefront with:

### Pages Created
- `/` - Homepage with featured products
- `/shop` - Product listing with filters & search
- `/shop/[handle]` - Product detail with variant selection
- `/cart` - Shopping cart
- `/checkout` - Checkout flow

### Components Created
- `Header.astro` - Site header with cart icon
- `Footer.astro` - Site footer
- `ProductCard.astro` - Reusable product card

### API & State
- `lib/medusa.ts` - Full Medusa v2 API client
- `stores/cart.ts` - Cart state with localStorage persistence

### Features
- Product browsing with pagination
- Search and category filtering
- Variant selection on product pages
- Add to cart functionality
- Cart management (update quantity, remove items)
- Checkout form with shipping address
- Responsive design with Tailwind CSS
- Rose/purple color scheme

## Testing the Storefront

1. **Browse Products**: Go to /shop to see all products
2. **View Product**: Click any product to see details
3. **Add to Cart**: Select variant and quantity, click "Add to Cart"
4. **View Cart**: Click cart icon in header
5. **Checkout**: Click "Proceed to Checkout" from cart

## API Requirements

The storefront expects these Medusa endpoints:
- `GET /store/products` - List products
- `GET /store/products/:id` - Get product
- `POST /store/carts` - Create cart
- `POST /store/carts/:id/line-items` - Add to cart
- `GET /store/carts/:id` - Get cart

Make sure your Medusa backend is running and accessible at the configured URL.

## Next Steps

For production, you'll want to:
1. Add payment processing (Stripe/PayPal via Medusa)
2. Implement user authentication
3. Add proper product images
4. Configure publishable API key
5. Set up analytics
6. Add SEO meta tags
7. Configure proper error handling

## Troubleshooting

**Products not loading?**
- Check that `PUBLIC_MEDUSA_BACKEND_URL` is correct in `.env`
- Verify Medusa backend is running
- Check browser console for API errors
- Ensure CORS is configured on Medusa backend

**Cart not working?**
- Check browser console for localStorage errors
- Ensure JavaScript is enabled
- Try clearing localStorage and refreshing

## File Overview

```
storefront/src/
├── components/
│   ├── Header.astro         (128 lines)
│   ├── Footer.astro         (82 lines)
│   └── ProductCard.astro    (76 lines)
├── layouts/
│   └── Layout.astro         (26 lines)
├── lib/
│   └── medusa.ts           (237 lines) - Medusa API client
├── pages/
│   ├── index.astro         (194 lines) - Homepage
│   ├── cart.astro          (258 lines) - Cart page
│   ├── checkout.astro      (375 lines) - Checkout
│   └── shop/
│       ├── index.astro     (233 lines) - Product listing
│       └── [handle].astro  (378 lines) - Product detail
└── stores/
    └── cart.ts             (234 lines) - Cart state

Total: ~2,400 lines of code
```

## Color Scheme

- **Primary**: Rose (#e11d48) - CTAs, links, highlights
- **Secondary**: Purple (#9333ea) - Accents, badges
- **Accent**: Pink (#ec4899) - Backgrounds, hover states
- **Neutral**: Gray scale for text and backgrounds

All colors use Tailwind's rose, purple, and pink palettes.
