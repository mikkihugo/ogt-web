import { OpsDb } from "../ops/service";
import { ExceptionService } from "./exception.service";
import { Logger } from "@medusajs/types";
import { MedusaContainer } from "@medusajs/framework";

interface RoutingCandidate {
  supplier_id: string;
  supplier_sku: string;
  cost: number;
  qty_available: number;
}

export class OrderRoutingService {
  private ops: OpsDb;
  private exceptionService: ExceptionService;
  private static instance: OrderRoutingService;
  private logger?: Logger;

  constructor() {
    this.ops = OpsDb.getInstance();
    this.exceptionService = ExceptionService.getInstance();
  }

  static getInstance(): OrderRoutingService {
    if (!OrderRoutingService.instance) {
      OrderRoutingService.instance = new OrderRoutingService();
    }
    return OrderRoutingService.instance;
  }

  setLogger(logger: Logger) {
    this.logger = logger;
    this.exceptionService.setLogger(logger);
  }

  /**
   * Main entry point: Route a Medusa Order to Suppliers
   * @param orderId Medusa Order ID
   * @param items Simplified line items (variant_id, quantity, unit_price, shop_id)
   */
  async routeOrder(
    orderId: string,
    items: {
      id: string;
      variant_id: string;
      quantity: number;
      unit_price: number;
    }[],
    shopId: string,
  ) {
    this.logger?.info(
      `Routing order ${orderId} for shop ${shopId} with ${items.length} lines.`,
    );

    const poGroups: Record<string, { supplierId: string; lines: any[] }> = {};

    for (const item of items) {
      try {
        // 1. Find Best Supplier
        const supplier = await this.findBestSupplier(
          item.variant_id,
          item.quantity,
        );

        if (!supplier) {
          await this.exceptionService.raise(
            shopId,
            "NO_SUPPLIER_FOUND",
            "high",
            { orderId, lineItemId: item.id, variantId: item.variant_id },
          );
          continue;
        }

        // 2. Add to Group
        if (!poGroups[supplier.supplier_id]) {
          poGroups[supplier.supplier_id] = {
            supplierId: supplier.supplier_id,
            lines: [],
          };
        }

        poGroups[supplier.supplier_id].lines.push({
          medusa_item_id: item.id,
          supplier_sku: supplier.supplier_sku,
          qty: item.quantity,
          cost: supplier.cost,
        });
      } catch (err: any) {
        this.logger?.error(`Error routing line item ${item.id}`, err);
        await this.exceptionService.raise(shopId, "ROUTING_ERROR", "critical", {
          orderId,
          lineItemId: item.id,
          error: err.message,
        });
      }
    }

    // 3. Create POs
    for (const group of Object.values(poGroups)) {
      await this.createPurchaseOrder(
        orderId,
        shopId,
        group.supplierId,
        group.lines,
      );
    }
  }

  private async findBestSupplier(
    variantId: string,
    qtyNeeded: number,
  ): Promise<RoutingCandidate | null> {
    // Logic: Profit-Aware Routing.
    // We select based on "Effective Cost" which penalizes unreliable suppliers.
    // Effective Cost = Unit Cost * (1 + (100 - ReliabilityScore)%)
    // Example: Score 80 means +20% cost penalty.

    const q = `
      SELECT 
        s.id as supplier_id,
        map.supplier_sku,
        inv.cost,
        inv.qty as qty_available,
        COALESCE(s.reliability_score, 100) as score,
        (inv.cost * (1 + (100 - COALESCE(s.reliability_score, 100))::decimal / 100)) as effective_cost
      FROM dropship.sku_map map
      JOIN dropship.supplier s ON s.id = map.supplier_id
      LEFT JOIN dropship.supplier_inventory inv 
        ON inv.supplier_id = map.supplier_id AND inv.supplier_sku = map.supplier_sku
      WHERE map.medusa_variant_id = $1
        AND s.status = 'active'
        AND inv.qty >= $2
        AND COALESCE(s.reliability_score, 100) > 50 -- Auto-Suppression Threshold
      ORDER BY effective_cost ASC
      LIMIT 1
    `;

    const { rows } = await this.ops
      .getQueryRunner()
      .then((pool) => pool.query(q, [variantId, qtyNeeded]));

    if (rows.length === 0) return null;

    return {
      supplier_id: rows[0].supplier_id,
      supplier_sku: rows[0].supplier_sku,
      cost: parseFloat(rows[0].cost),
      qty_available: rows[0].qty_available,
    };
  }

  private async createPurchaseOrder(
    medusaOrderId: string,
    shopId: string,
    supplierId: string,
    lines: any[],
  ) {
    const poId = `po_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    this.logger?.info(`Creating PO ${poId} for Supplier ${supplierId}`);

    const client = await this.ops.getQueryRunner();

    // Transaction ideally
    await client.query(
      `INSERT INTO dropship.purchase_order (id, medusa_order_id, shop_id, supplier_id, status)
           VALUES ($1, $2, $3, $4, 'created')`,
      [poId, medusaOrderId, shopId, supplierId],
    );

    for (const line of lines) {
      const lineId = `pol_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      await client.query(
        `INSERT INTO dropship.purchase_order_line (id, purchase_order_id, medusa_order_item_id, supplier_sku, qty, unit_cost)
               VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          lineId,
          poId,
          line.medusa_item_id,
          line.supplier_sku,
          line.qty,
          line.cost,
        ],
      );
    }

    this.logger?.info(`PO ${poId} created successfully.`);

    // 4. Log Decision (Phase 8)
    try {
      await client.query(
        `
                INSERT INTO dropship.event_history (event_type, entity_id, meta)
                VALUES ($1, $2, $3)
            `,
        [
          "routing_decision",
          medusaOrderId,
          JSON.stringify({
            po_id: poId,
            supplier_id: supplierId,
            line_count: lines.length,
            reason: "Best Effective Cost",
          }),
        ],
      );
    } catch (e) {
      // Non-blocking logging failure
      this.logger?.warn(
        `Failed to log routing decision history: ${(e as Error).message}`,
      );
    }
  }
}
