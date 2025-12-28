# OGT-Web Project Review

## Overview

OGT-Web is a modern e-commerce platform built with a clear separation of concerns between backend and frontend.

- **Backend**: MedusaJS v2 (Headless Commerce Engine)
- **Storefront**: Astro + React + TailwindCSS
- **Content Management**: Keystatic (Embedded CMS)

## Key Features

### Backend (Medusa v2)

- **Modular Architecture**: Uses Medusa's module system.
- **Payment Integration**: Stripe integration configured for Card, Apple Pay, and Google Pay.
- **Custom Modules**:
  - `blog`: A custom module for managing blog posts, defining `Post` models with fields for content, SEO, and publishing status.
- **Workflows**: Includes standard Medusa workflows for seeding products, inventory, and sales channels.
- **Deployment**: Nix-based builds using `flake.nix` (NixOS 25.11) with `nix2container`. Deployed to Hetzner via Docker Compose (`docker-compose.yml`) utilizing `caddy` as a reverse proxy sidecar.

### Storefront (Astro)

- **Rendering**: Server-Side Rendering (SSR) mode using `@astrojs/node` adapter.
- **Styling**: TailwindCSS v4 for utility-first styling.
- **Content**:
  - Integrated Blog section fetching data from the custom backend module.
  - Product catalog with categories (Couples, Self-Care, Wellness).
- **Middleware**: Multi-tenant/Region support via `middleware.ts`, handling locale and currency based on hostname.

## Project Structure

- `src/`: Backend source code (API, Modules, Subscribers).
- `storefront/`: Frontend source code (Astro pages, Components).
- `medusa-config.ts`: Main configuration for database, modules, and plugins.
