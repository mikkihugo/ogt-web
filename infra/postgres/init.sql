
CREATE DATABASE medusa_db;
CREATE DATABASE strapi_db;
CREATE DATABASE chatwoot_db;
CREATE DATABASE ops_db;

\c ops_db

CREATE SCHEMA IF NOT EXISTS ops;

-- Shops
CREATE TABLE IF NOT EXISTS ops.shop (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'active', -- active|paused|maintenance
  shop_type       TEXT NOT NULL DEFAULT 'store',  -- store|blog|funnel|mixed

  default_region  TEXT NOT NULL,                  -- Medusa region id
  currency_code   TEXT NOT NULL,
  default_locale  TEXT NOT NULL DEFAULT 'en',

  theme_tokens    JSONB NOT NULL DEFAULT '{}'::jsonb,     -- design tokens
  catalog_rules   JSONB NOT NULL DEFAULT '{}'::jsonb,     -- include/exclude rules
  pricing_rules   JSONB NOT NULL DEFAULT '{}'::jsonb,     -- markup rules etc.

  marketing_config JSONB NOT NULL DEFAULT '{}'::jsonb,    -- GA4 ids, pixels, merchant center
  support_config   JSONB NOT NULL DEFAULT '{}'::jsonb,    -- chatwoot website token, inbox id

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ops.shop_domain (
  domain          TEXT PRIMARY KEY,
  shop_id         TEXT NOT NULL REFERENCES ops.shop(id) ON DELETE CASCADE,
  is_primary      BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_shop_domain_shop_id ON ops.shop_domain(shop_id);

-- Dropship
CREATE SCHEMA IF NOT EXISTS dropship;

CREATE TABLE IF NOT EXISTS dropship.supplier (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  base_url TEXT,
  auth_type TEXT NOT NULL DEFAULT 'api_key', -- api_key|oauth|basic|custom
  rate_limit_per_min INT NOT NULL DEFAULT 60,
  regions_supported TEXT[] NOT NULL DEFAULT ARRAY[]::text[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dropship.supplier_inventory (
  supplier_id TEXT NOT NULL REFERENCES dropship.supplier(id) ON DELETE CASCADE,
  supplier_sku TEXT NOT NULL,
  qty INT NOT NULL,
  cost NUMERIC(12,4),
  currency_code TEXT,
  lead_time_days INT,
  ships_from_region TEXT,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (supplier_id, supplier_sku)
);

CREATE TABLE IF NOT EXISTS dropship.sku_map (
  supplier_id TEXT NOT NULL REFERENCES dropship.supplier(id) ON DELETE CASCADE,
  supplier_sku TEXT NOT NULL,
  medusa_variant_id TEXT NOT NULL,
  mapping_confidence INT NOT NULL DEFAULT 100,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (supplier_id, supplier_sku)
);

CREATE TABLE IF NOT EXISTS dropship.purchase_order (
  id TEXT PRIMARY KEY,
  medusa_order_id TEXT NOT NULL,
  shop_id TEXT NOT NULL REFERENCES ops.shop(id),
  supplier_id TEXT NOT NULL REFERENCES dropship.supplier(id),
  status TEXT NOT NULL DEFAULT 'created', -- created|submitted|accepted|rejected|shipped|failed|cancelled
  supplier_ref TEXT,
  error_code TEXT,
  error_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dropship.purchase_order_line (
  id TEXT PRIMARY KEY,
  purchase_order_id TEXT NOT NULL REFERENCES dropship.purchase_order(id) ON DELETE CASCADE,
  medusa_order_item_id TEXT NOT NULL,
  supplier_sku TEXT NOT NULL,
  qty INT NOT NULL,
  unit_cost NUMERIC(12,4),
  status TEXT NOT NULL DEFAULT 'created'
);

CREATE TABLE IF NOT EXISTS dropship.ops_exception (
  id TEXT PRIMARY KEY,
  shop_id TEXT NOT NULL REFERENCES ops.shop(id),
  type TEXT NOT NULL,           -- STOCKOUT|PO_SUBMIT_FAILED|ADDRESS_INVALID|DELAYED|SPLIT_SHIPMENT
  severity TEXT NOT NULL,       -- low|medium|high|critical
  entity_ref JSONB NOT NULL,    -- {order_id, po_id, supplier_id, ...}
  status TEXT NOT NULL DEFAULT 'open', -- open|in_progress|resolved|ignored
  assigned_to TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dropship.shop_supplier_policy (
  shop_id TEXT NOT NULL REFERENCES ops.shop(id) ON DELETE CASCADE,
  supplier_id TEXT NOT NULL REFERENCES dropship.supplier(id) ON DELETE CASCADE,
  buffer_stock INT NOT NULL DEFAULT 0,
  min_margin NUMERIC(6,4) NOT NULL DEFAULT 0.20,
  markup_rules JSONB NOT NULL DEFAULT '{}'::jsonb,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (shop_id, supplier_id)
);

-- Marketing
CREATE SCHEMA IF NOT EXISTS marketing;

CREATE TABLE IF NOT EXISTS marketing.shop_ad_account (
  id TEXT PRIMARY KEY,
  shop_id TEXT NOT NULL REFERENCES ops.shop(id),
  platform TEXT NOT NULL, -- google_ads|meta_ads
  external_account_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  credential_ref TEXT NOT NULL, -- points to encrypted secret storage
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS marketing.ad_campaign_daily (
  shop_id TEXT NOT NULL REFERENCES ops.shop(id),
  platform TEXT NOT NULL,
  account_id TEXT NOT NULL,
  date DATE NOT NULL,
  campaign_id TEXT NOT NULL,
  campaign_name TEXT,
  spend NUMERIC(14,4) NOT NULL DEFAULT 0,
  impressions BIGINT NOT NULL DEFAULT 0,
  clicks BIGINT NOT NULL DEFAULT 0,
  conversions NUMERIC(14,4) NOT NULL DEFAULT 0,
  conversion_value NUMERIC(14,4) NOT NULL DEFAULT 0,
  PRIMARY KEY (shop_id, platform, account_id, date, campaign_id)
);

-- Seed Initial Shops
INSERT INTO ops.shop(id, name, shop_type, default_region, currency_code, default_locale, marketing_config, support_config)
VALUES
('shop_us', 'US Shop', 'store', 'reg_us', 'USD', 'en', '{"ga4_measurement_id":"G-US","meta_pixel_id":"111"}', '{"chatwoot_base_url":"https://support.example.com","chatwoot_website_token":"tok_us","chatwoot_inbox_id":1}'),
('shop_eu', 'EU Shop', 'store', 'reg_eu', 'EUR', 'en', '{"ga4_measurement_id":"G-EU","meta_pixel_id":"222"}', '{"chatwoot_base_url":"https://support.example.com","chatwoot_website_token":"tok_eu","chatwoot_inbox_id":2}'),
('brand_b', 'Brand B', 'store', 'reg_eu', 'EUR', 'sv', '{"ga4_measurement_id":"G-BB"}', '{"chatwoot_base_url":"https://support.example.com","chatwoot_website_token":"tok_bb","chatwoot_inbox_id":3}'),
('content_hub', 'Content Hub', 'blog', 'reg_eu', 'EUR', 'en', '{}', '{"chatwoot_base_url":"https://support.example.com","chatwoot_website_token":"tok_blog","chatwoot_inbox_id":4}'),
('funnel_gadget', 'Best Gadget Ever', 'funnel', 'reg_us', 'USD', 'en', '{"meta_pixel_id":"999"}', '{"chatwoot_base_url":"https://support.example.com","chatwoot_website_token":"tok_fun","chatwoot_inbox_id":5}')
ON CONFLICT DO NOTHING;

INSERT INTO ops.shop_domain(domain, shop_id, is_primary) VALUES
('us.example.com','shop_us',true),
('eu.example.com','shop_eu',true),
('brandb.example.com','brand_b',true),
('blog.example.com','content_hub',true),
('best-gadget-ever.com','funnel_gadget',true)
ON CONFLICT DO NOTHING;
