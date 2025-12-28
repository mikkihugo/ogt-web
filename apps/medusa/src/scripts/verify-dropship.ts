import { MedusaContainer } from "@medusajs/framework";
import { SupplierService } from "../modules/dropship/supplier.service";
import { InventoryService } from "../modules/dropship/inventory.service";
import syncSupplierInventory from "../scripts/sync-supplier";

export default async function (container: MedusaContainer) {
  const logger = container.resolve("logger");
  const supplierService = SupplierService.getInstance();

  logger.info("Starting Dropship Verification...");

  // 1. Setup Test Data
  const supplierId = "supp_test_01";
  await supplierService
    .createSupplier({
      id: supplierId,
      name: "Test Supplier",
      status: "active",
      auth_type: "api_key",
      rate_limit_per_min: 60,
    })
    .catch(() => logger.info("Supplier already exists, proceeding..."));

  // 2. Mock SKU Mapping (Direct SQL for speed, as we didn't build SkuMapService yet)
  const ops = (supplierService as any).ops; // access private OpsDb
  await ops.getQueryRunner().then((pool: any) =>
    pool.query(
      `
      INSERT INTO dropship.sku_map(supplier_id, supplier_sku, medusa_variant_id)
      VALUES ($1, 'GG-001', 'variant_123')
      ON CONFLICT DO NOTHING
    `,
      [supplierId],
    ),
  );

  // 3. Mock Service (Not needed for stubbed dry-run)
  // container.register("productVariantService", { resolve: () => mockVariantService });

  // 4. Run Sync
  // We mock the feed URL since the job uses a hardcoded CSV string for verification currently
  await syncSupplierInventory(container, supplierId, "http://mock-feed.csv");

  // 5. Verify Order Routing
  const { OrderRoutingService } = await import(
    // @ts-ignore - dynamic import of local module
    "../modules/dropship/order-routing.service"
  );
  const routingService = OrderRoutingService.getInstance();
  routingService.setLogger(logger);

  logger.info("Verifying Order Routing...");
  await routingService.routeOrder(
    "ord_test_001",
    [
      {
        id: "item_test_1",
        variant_id: "variant_123",
        quantity: 5,
        unit_price: 1500,
      },
    ],
    "shop_us",
  );

  // Check PO existence
  const opsRouting = (supplierService as any).ops;
  const { rows: poRows } = await opsRouting
    .getQueryRunner()
    .then((pool: any) =>
      pool.query(
        `SELECT * FROM dropship.purchase_order WHERE medusa_order_id = 'ord_test_001'`,
      ),
    );

  if (poRows.length > 0) {
    logger.info(
      `SUCCESS: PO created: ${poRows[0].id} for Supplier ${poRows[0].supplier_id}`,
    );
  } else {
    logger.error("FAILURE: No PO created for routed order.");
    // Check exceptions
    const { rows: excRows } = await opsRouting
      .getQueryRunner()
      .then((pool: any) =>
        pool.query(
          `SELECT * FROM dropship.ops_exception WHERE entity_ref->>'orderId' = 'ord_test_001'`,
        ),
      );
    if (excRows.length > 0) {
      logger.warn(
        `Routing Exception Found: ${excRows[0].type} - ${excRows[0].notes}`,
      );
    }
  }

  logger.info("Dropship Verification Complete.");
}
