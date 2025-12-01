# Orgasm Toy - Astro Storefront

A modern, professional Astro-based e-commerce storefront for Medusa v2.

## Features

- **Product Browsing**: Browse products with filtering, search, and pagination
- **Product Details**: Detailed product pages with variant selection
- **Shopping Cart**: Full-featured cart with localStorage persistence
- **Checkout**: Complete checkout flow (demo implementation)
- **Responsive Design**: Mobile-first design with Tailwind CSS
- **API Integration**: Seamless integration with Medusa v2 backend

## Tech Stack

- **Framework**: Astro 5 (SSR mode)
- **Styling**: Tailwind CSS v4
- **State Management**: Nanostores with persistent storage
- **Backend**: Medusa v2 API
- **Deployment**: Node.js adapter for standalone deployment

## Getting Started

### Prerequisites

- Node.js 18+ or use the Nix dev shell
- Medusa v2 backend running at `https://api.orgasmtoy.com`

### Installation

1. Install dependencies:
```bash
cd storefront
yarn install
```

2. Configure environment variables:
```bash
cp .env.example .env
```

Edit `.env` and set:
- `PUBLIC_MEDUSA_BACKEND_URL`: Your Medusa backend URL
- `PUBLIC_MEDUSA_PUBLISHABLE_KEY`: Your Medusa publishable API key (optional)

### Development

Run the development server:
```bash
yarn dev
```

The storefront will be available at `http://localhost:4321`

### Building for Production

```bash
yarn build
```

The built files will be in the `dist/` directory.

### Preview Production Build

```bash
yarn preview
```

## Project Structure

```
storefront/
├── src/
│   ├── components/       # Reusable Astro components
│   │   ├── Header.astro
│   │   ├── Footer.astro
│   │   └── ProductCard.astro
│   ├── layouts/          # Page layouts
│   │   └── Layout.astro
│   ├── lib/              # Utilities and API clients
│   │   └── medusa.ts     # Medusa API client
│   ├── pages/            # Route pages
│   │   ├── index.astro   # Homepage
│   │   ├── cart.astro    # Shopping cart
│   │   ├── checkout.astro # Checkout page
│   │   └── shop/
│   │       ├── index.astro       # Product listing
│   │       └── [handle].astro    # Product detail
│   ├── stores/           # State management
│   │   └── cart.ts       # Cart state with nanostores
│   └── styles/           # Global styles
├── public/               # Static assets
├── astro.config.mjs      # Astro configuration
├── package.json
└── tsconfig.json
```

## Key Pages

- **/** - Homepage with featured products
- **/shop** - Product listing with filters and search
- **/shop/[handle]** - Individual product details
- **/cart** - Shopping cart
- **/checkout** - Checkout flow

## Medusa API Integration

The storefront uses the Medusa Store API endpoints:

- `GET /store/products` - List products
- `GET /store/products/:id` - Get product details
- `POST /store/carts` - Create cart
- `POST /store/carts/:id/line-items` - Add to cart
- `GET /store/carts/:id` - Get cart details

See `src/lib/medusa.ts` for the complete API client implementation.

## Cart Management

The cart uses nanostores for state management with localStorage persistence:

- Cart data is stored in `localStorage` under the key `cart-storage`
- Cart state syncs across browser tabs
- Custom events trigger UI updates when cart changes

## Styling

The storefront uses a tasteful rose/purple color scheme:

- Primary: Rose (rose-600, rose-50)
- Secondary: Purple (purple-600, purple-50)
- Accent: Pink (pink-600, pink-50)

All styling is done with Tailwind CSS v4 utility classes.

## TODO: Production Enhancements

For a production deployment, consider:

1. **Payment Processing**: Integrate Stripe/PayPal via Medusa payment plugins
2. **User Authentication**: Add customer login/registration
3. **Order History**: Display past orders for logged-in users
4. **Search**: Implement advanced product search with Algolia or MeiliSearch
5. **Reviews**: Add product reviews and ratings
6. **Wishlist**: Save products for later
7. **Email**: Order confirmation and shipping notifications
8. **Analytics**: Add Google Analytics or similar
9. **SEO**: Meta tags, structured data, sitemap
10. **A/B Testing**: Optimize conversion rates

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PUBLIC_MEDUSA_BACKEND_URL` | Medusa backend URL | Yes |
| `PUBLIC_MEDUSA_PUBLISHABLE_KEY` | Medusa publishable API key | No |

## License

Proprietary - Orgasm Toy
