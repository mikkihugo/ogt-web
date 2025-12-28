import { DropshipService } from "./service";

export async function runSupplierSync() {
  const svc = new DropshipService();
  // In production: list active suppliers from ops_db and fan out with concurrency limits
  // await svc.syncSupplier("supplier_a");
  console.log("Sync job triggered");
}
