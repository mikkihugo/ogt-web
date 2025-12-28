import { MedusaRequest, MedusaResponse } from "@medusajs/framework";
import { OpsDb } from "../../../../modules/ops/service";

export async function GET(
  req: MedusaRequest,
  res: MedusaResponse,
): Promise<void> {
  const ops = OpsDb.getInstance();
  const pool = await ops.getQueryRunner();

  // 1. Exception Stats
  const exceptionQuery = `
    SELECT 
        severity, 
        COUNT(*) as count 
    FROM dropship.ops_exception 
    WHERE status = 'open' 
    GROUP BY severity
  `;
  const { rows: exceptions } = await pool.query(exceptionQuery);

  // 2. Recent PO Stats
  const poQuery = `
    SELECT 
        status, 
        COUNT(*) as count 
    FROM dropship.purchase_order 
    WHERE created_at > NOW() - INTERVAL '24 HOURS' 
    GROUP BY status
  `;
  const { rows: pos } = await pool.query(poQuery);

  // 3. Supplier Sync Health (Mocked for now, usually would query job_metadata table)
  const syncHealth = {
    status: "healthy",
    last_sync: new Date().toISOString(),
    failing_suppliers: 0,
  };

  res.json({
    ops_health: {
      exceptions: exceptions.reduce((acc: any, row: any) => {
        acc[row.severity] = parseInt(row.count);
        return acc;
      }, {}),
      recent_orders: pos.reduce((acc: any, row: any) => {
        acc[row.status] = parseInt(row.count);
        return acc;
      }, {}),
      sync: syncHealth,
    },
  });
}
