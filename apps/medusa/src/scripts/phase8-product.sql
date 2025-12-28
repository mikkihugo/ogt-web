-- Phase 8.2: Product Metrics for Kill Switches
CREATE TABLE IF NOT EXISTS dropship.product_metrics (
    medusa_product_id VARCHAR(255) PRIMARY KEY,
    total_sales INT DEFAULT 0,
    return_count INT DEFAULT 0,
    ad_spend DECIMAL(10,2) DEFAULT 0.00,
    suppressed BOOLEAN DEFAULT FALSE,
    last_updated_at TIMESTAMP DEFAULT NOW()
);

-- Event History already exists, but ensure we have an index for product lookups if needed
CREATE INDEX IF NOT EXISTS idx_event_history_product_actor ON dropship.event_history(actor) WHERE actor = 'product_scorer';
