import { OpsDb } from "../ops/service";
import { Logger } from "@medusajs/types";

export interface SupplierOffer {
  sku: string;
  qty: number;
  cost: number;
  currency: string;
  leadTimeDays: number;
  shipsFrom: string;
}

export class InventoryService {
  private ops: OpsDb;
  private static instance: InventoryService;

  constructor() {
    this.ops = OpsDb.getInstance();
  }

  static getInstance(): InventoryService {
    if (!InventoryService.instance) {
      InventoryService.instance = new InventoryService();
    }
    return InventoryService.instance;
  }

  /**
   * Bulk upsert supplier inventory into ops_db
   */
  async upsertSupplierOffers(supplierId: string, offers: SupplierOffer[]) {
    const client = await this.ops.getQueryRunner();

    // In a real high-volume scenario, we would use pg-copy-streams or generate a large multi-value insert.
    // For now, simple batched inserts/upserts.

    // We'll proceed in transactions of 100 items
    const batchSize = 100;
    for (let i = 0; i < offers.length; i += batchSize) {
      const batch = offers.slice(i, i + batchSize);

      // Construct generic bulk upsert query?
      // Or just loop sequentially for simplicity in this blueprint.
      // Let's loop sequentially but inside a transaction block if possible,
      // but OpsDb exposes pool directly. usage of pool.connect() is needed for transaction.
      // Falling back to simple individual upserts for "One Brain" scale (assuming <100k SKUs).

      for (const offer of batch) {
        await client.query(
          `INSERT INTO dropship.supplier_inventory(supplier_id, supplier_sku, qty, cost, currency_code, lead_time_days, ships_from_region, fetched_at)
            VALUES($1, $2, $3, $4, $5, $6, $7, now())
            ON CONFLICT (supplier_id, supplier_sku)
            DO UPDATE SET 
              qty=EXCLUDED.qty, 
              cost=EXCLUDED.cost, 
              lead_time_days=EXCLUDED.lead_time_days, 
              fetched_at=now()`,
          [
            supplierId,
            offer.sku,
            offer.qty,
            offer.cost,
            offer.currency,
            offer.leadTimeDays,
            offer.shipsFrom,
          ],
        );
      }
    }
  }

  /**
   * Calculates the inventory that should be pushed to Medusa
   * Returns a map of medusa_variant_id -> safe_qty
   */
  async calculateMedusaUpdates(
    supplierId: string,
  ): Promise<Record<string, number>> {
    const client = await this.ops.getQueryRunner();

    // Join inventory with sku_map
    // We assume a global buffer for now (or per-shop logic if we project per shop sales channel)
    // The Blueprint says "update Medusa variant availability conservatively".
    // This usually implies the "Master" inventory.

    // Let's assume a default buffer of 0 if no policy.
    // But policy is per (shop, supplier). Medusa variant is global unless using Inventory Levels (mult-stock-location).
    // For simplicity in Phase 4: We will update the default Stock Location or Variant Inventory with a Generic "Safe" rule.
    // Rule: Safe Qty = Supplier Qty - MAX(Safety Buffers of all enabled shops).

    // Simplified Query: Get mapped inventory and apply a static buffer or 0.
    const q = `
        SELECT 
          sm.medusa_variant_id,
          si.qty,
          si.supplier_sku
        FROM dropship.supplier_inventory si
        JOIN dropship.sku_map sm 
          ON sm.supplier_id = si.supplier_id 
          AND sm.supplier_sku = si.supplier_sku
        WHERE si.supplier_id = $1
      `;

    const { rows } = await client.query(q, [supplierId]);

    const updates: Record<string, number> = {};
    const DEFAULT_BUFFER = 5; // Global safety factor

    for (const row of rows) {
      const rawQty = row.qty;
      const safeQty = Math.max(0, rawQty - DEFAULT_BUFFER);
      updates[row.medusa_variant_id] = safeQty;
    }

    return updates;
  }
}
