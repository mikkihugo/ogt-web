import { MedusaContainer } from "@medusajs/framework";
import { Logger } from "@medusajs/types";
import { OpsDb } from "../modules/ops/service";

// Phase 8.2: Product Scoring & Kill Switches
export const scoreProductsJob = async (container: MedusaContainer) => {
    const logger = container.resolve("logger") as Logger;
    const ops = OpsDb.getInstance();
    const pool = await ops.getQueryRunner();

    logger.info("Starting Product Scoring Job...");

    try {
        // 1. Calculate stats (Returns)
        // Mocking 'line_item_status' table or similar logic since standard Medusa schema is complex.
        // We assume we can join orders->lines.
        // For this demo, we mock the query.

        // "Find products with > 10% returns in last 30 days"
        // In real Medusa, this requires joining `return` -> `return_item` -> `line_item` -> `variant`.

        // Mock Logic:
        const badProducts = [
            { id: "prod_BAD_SKU", return_rate: 15, sales: 100 }
        ];

        for (const p of badProducts) {
            logger.info(`Product ${p.id} has ${p.return_rate}% return rate. Activating Kill Switch.`);

            // 2. Update Metrics
            // using the table we defined in phase8-product.sql
            const q = `
                INSERT INTO dropship.product_metrics (medusa_product_id, return_rate, suppressed)
                VALUES ($1, $2, TRUE)
                ON CONFLICT (medusa_product_id) 
                DO UPDATE SET return_rate = $2, suppressed = TRUE;
             `;
            await pool.query(q, [p.id, p.return_rate]);

            // 3. Log History
            await pool.query(`
                INSERT INTO dropship.event_history (event_type, entity_id, meta)
                VALUES ('product_kill_switch', $1, $2)
             `, [p.id, JSON.stringify({ reason: "High Return Rate", rate: p.return_rate })]);
        }

    } catch (err) {
        logger.error("Product Scoring Failed", err);
    }
}
