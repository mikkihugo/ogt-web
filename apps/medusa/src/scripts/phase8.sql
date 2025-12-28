-- 1. Supplier Reliability Score
ALTER TABLE dropship.supplier 
ADD COLUMN IF NOT EXISTS reliability_score INT DEFAULT 100;

-- 2. Event History (Time Travel / Audit)
CREATE TABLE IF NOT EXISTS dropship.event_history (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL, -- 'routing_decision', 'price_change', 'supplier_score_update'
    entity_id VARCHAR(100) NOT NULL, -- ref to order_id, product_id, supplier_id
    actor VARCHAR(50) DEFAULT 'system',
    meta JSONB DEFAULT '{}', -- input signals, rule version, outcome
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_history_entity ON dropship.event_history(entity_id);
