import { MedusaContainer } from "@medusajs/framework";
import { Logger } from "@medusajs/types";
import { OpsDb } from "../modules/ops/service";

// Phase 8: Supplier Scoring Job
// Runs daily to update 'reliability_score' based on recent performance.
export const scoreSuppliersJob = async (container: MedusaContainer) => {
  const logger = container.resolve("logger") as Logger;
  const ops = OpsDb.getInstance();
  const pool = await ops.getQueryRunner();

  logger.info("Starting Supplier Scoring Job...");

  try {
    // 1. Fetch performance stats per supplier (Last 30 days)
    // We look at PO status. 'canceled' = failure. 'completed' = success.
    // TODO: In future, use 'delivered_at' vs 'promised_at' for strict SLA checking.
    const statsQuery = `
            SELECT 
                supplier_id,
                COUNT(*) as total_orders,
                COUNT(*) FILTER (WHERE status = 'canceled') as failures
            FROM dropship.purchase_order
            WHERE created_at > NOW() - INTERVAL '30 DAYS'
            GROUP BY supplier_id
        `;

    const { rows: stats } = await pool.query(statsQuery);

    // 2. Calculate and Update Scores
    for (const stat of stats) {
      const total = parseInt(stat.total_orders);
      const failures = parseInt(stat.failures);

      // Basic Formula: Start at 100. Deduct 10 points per 1% failure rate?
      // Let's be simpler: Score = Success Rate %.
      // If No orders, keep 100 (benefit of doubt).

      let score = 100;
      if (total > 0) {
        const successRate = ((total - failures) / total) * 100;
        score = Math.round(successRate);
      }

      // Floor at 0, Cap at 100
      score = Math.max(0, Math.min(100, score));

      logger.info(
        `Supplier ${stat.supplier_id}: ${failures}/${total} failures. Score: ${score}`,
      );

      await pool.query(
        `
                UPDATE dropship.supplier 
                SET reliability_score = $1
                WHERE id = $2
            `,
        [score, stat.supplier_id],
      );

      // 3. Log Event for History (Time Travel)
      await pool.query(
        `
                INSERT INTO dropship.event_history 
                (event_type, entity_id, meta)
                VALUES ($1, $2, $3)
            `,
        [
          "supplier_score_update",
          stat.supplier_id,
          JSON.stringify({
            old_score: "unknown",
            new_score: score,
            reason: `30-day stats: ${failures}/${total} failures`,
          }),
        ],
      );
    }

    logger.info("Supplier Scoring Complete.");
  } catch (err) {
    logger.error("Failed to score suppliers", err as Error);
  }
};
