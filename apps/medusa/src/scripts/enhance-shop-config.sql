-- Add missing configuration columns to ops.shop
-- These allow for full frontend flexibility and compliance

-- 1. Legal Config (Required for Merchant Center)
ALTER TABLE ops.shop 
ADD COLUMN IF NOT EXISTS legal_config JSONB NOT NULL DEFAULT '{}'::jsonb;
-- Example: { "company_name": "...", "address": "...", "policy_links": { "privacy": "..." } }

-- 2. Navigation / Menus (Dynamic Frontend)
ALTER TABLE ops.shop 
ADD COLUMN IF NOT EXISTS navigation_config JSONB NOT NULL DEFAULT '{}'::jsonb;
-- Example: { "header": [ { "label": "Shop", "href": "/store" } ], "footer": [...] }

-- 3. SEO Defaults (Meta Templates)
ALTER TABLE ops.shop 
ADD COLUMN IF NOT EXISTS seo_config JSONB NOT NULL DEFAULT '{}'::jsonb;
-- Example: { "title_template": "%s | Brand", "default_description": "..." }

-- 4. Payment Preferences (B2B vs Retail)
ALTER TABLE ops.shop 
ADD COLUMN IF NOT EXISTS payment_config JSONB NOT NULL DEFAULT '{}'::jsonb;
-- Example: { "methods": ["card", "apple_pay"], "force_manual_capture": false }
