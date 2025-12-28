import { MedusaContainer } from "@medusajs/framework";
import { OpsDb } from "../modules/ops/service";
import { Logger } from "@medusajs/types";

export default async function (container: MedusaContainer) {
  const logger = container.resolve("logger") as Logger;
  logger.info("Starting Adaptive Logistics Schema Upgrade (Phase 8)...");

  const ops = OpsDb.getInstance();
  const pool = await ops.getQueryRunner();

  try {
    // 1. Supplier Reliability Score
    logger.info("Adding reliability_score to dropship.supplier...");
    await pool.query(`
            ALTER TABLE dropship.supplier 
            ADD COLUMN IF NOT EXISTS reliability_score INT DEFAULT 100;
        `);

    // 2. Event History (Time Travel / Audit)
    // Stores inputs and outcomes of automated decisions.
    logger.info("Creating dropship.event_history table...");
    await pool.query(`
            CREATE TABLE IF NOT EXISTS dropship.event_history (
                id SERIAL PRIMARY KEY,
                event_type VARCHAR(50) NOT NULL, -- 'routing_decision', 'price_change', 'supplier_score_update'
                entity_id VARCHAR(100) NOT NULL, -- ref to order_id, product_id, supplier_id
                actor VARCHAR(50) DEFAULT 'system',
                meta JSONB DEFAULT '{}', -- input signals, rule version, outcome
                created_at TIMESTAMP DEFAULT NOW()
            );
        `);

    // Index for fast lookups by entity (e.g., "Show me all routing decisions for Order X")
    await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_event_history_entity ON dropship.event_history(entity_id);
        `);

    logger.info("✅ Adaptive Logistics Schema Applied Successfully.");
  } catch (err) {
    logger.error("Failed to apply Adaptive Schema", err as Error);
  }
}
