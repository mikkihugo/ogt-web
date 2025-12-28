import { MedusaContainer } from "@medusajs/framework";
import { Logger } from "@medusajs/types";
import { SupplierService } from "../modules/dropship/supplier.service";
import {
  InventoryService,
  SupplierOffer,
} from "../modules/dropship/inventory.service";

// Mock CSV Parser
function parseCsv(csvContent: string): any[] {
  // Simple line-by-line split for blueprint
  const lines = csvContent.split("\n");
  const headers = lines[0].split(",").map((h) => h.trim());
  const results = [];

  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = lines[i].split(",").map((v) => v.trim());
    const row: any = {};
    headers.forEach((h, idx) => (row[h] = values[idx]));
    results.push(row);
  }
  return results;
}

export default async function syncSupplierInventory(
  container: MedusaContainer,
  supplierId: string,
  feedUrl: string,
) {
  const logger = container.resolve("logger") as Logger;
  // const productVariantService = container.resolve("productVariantService");

  const supplierService = SupplierService.getInstance();
  const inventoryService = InventoryService.getInstance();

  const supplier = await supplierService.getSupplier(supplierId);
  if (!supplier || supplier.status !== "active") {
    logger.warn(`Skipping sync for non-active supplier: ${supplierId}`);
    return;
  }

  logger.info(`Starting sync for supplier: ${supplier.name}`);

  try {
    // 1. Fetch Feed (Mocked fetch)
    // const response = await fetch(feedUrl); const text = await response.text();
    // Use dummy CSV for blueprint verification
    const csvContent = `SKU,Qty,Cost
GG-001,50,10.00
GG-002,0,20.00`;

    const rawRows = parseCsv(csvContent);

    // 2. Map to SupplierOffer
    const offers: SupplierOffer[] = rawRows.map((r) => ({
      sku: r["SKU"],
      qty: parseInt(r["Qty"] || "0"),
      cost: parseFloat(r["Cost"] || "0"),
      currency: "USD", // Fallback, usually comes from feed or shop default
      leadTimeDays: 3,
      shipsFrom: "default",
    }));

    // 3. Upsert to OpsDb
    await inventoryService.upsertSupplierOffers(supplierId, offers);
    logger.info(`Upserted ${offers.length} offers to OpsDB.`);

    // 4. Calculate Medusa Updates
    const updates = await inventoryService.calculateMedusaUpdates(supplierId);

    // 5. Apply to Medusa
    // This loops. For thousands of SKUs, we'd use a bulk update strategy or workflow.
    // TODO: Implement Medusa v2 Inventory Module update
    let updatedCount = 0;
    for (const [variantId, qty] of Object.entries(updates)) {
      try {
        // In Medusa v2 we interact with IInventoryService or use a Workflow.
        // Stubbing for verification of Ops Logic.
        logger.info(`[DryRun] Would update variant ${variantId} to qty ${qty}`);
        updatedCount++;
      } catch (err) {
        logger.error(`Failed to update variant ${variantId}`, err as Error);
      }
    }

    logger.info(`Sync complete. Updated ${updatedCount} variants in Medusa.`);
  } catch (err) {
    logger.error(`Sync failed for supplier ${supplierId}`, err as Error);
    throw err;
  }
}
