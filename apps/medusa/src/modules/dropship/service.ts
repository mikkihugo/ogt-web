import { OpsDb } from "../ops/service";

export class DropshipService {
    private ops: OpsDb;
    constructor() {
        this.ops = OpsDb.getInstance();
    }

    async syncSupplier(supplierId: string) {
        // 1) fetch supplier data (replace with real connector)
        const items = await this.fetchSupplierInventory(supplierId);

        // 2) upsert into ops_db
        const client = await this.ops.getQueryRunner();
        // Transaction logic would go here
        for (const it of items) {
            await client.query(
                `INSERT INTO dropship.supplier_inventory(supplier_id, supplier_sku, qty, cost, currency_code, lead_time_days, ships_from_region, fetched_at)
           VALUES($1,$2,$3,$4,$5,$6,$7, now())
           ON CONFLICT (supplier_id, supplier_sku)
           DO UPDATE SET qty=EXCLUDED.qty, cost=EXCLUDED.cost, currency_code=EXCLUDED.currency_code,
                         lead_time_days=EXCLUDED.lead_time_days, ships_from_region=EXCLUDED.ships_from_region, fetched_at=now()`,
                [supplierId, it.sku, it.qty, it.cost, it.currency, it.leadTimeDays, it.shipsFrom]
            );
        }
    }

    private async fetchSupplierInventory(_supplierId: string) {
        // Replace with real HTTP connector per supplier
        return [
            { sku: "SUP-001", qty: 10, cost: 12.5, currency: "USD", leadTimeDays: 3, shipsFrom: "us" },
            { sku: "SUP-002", qty: 0, cost: 22.0, currency: "USD", leadTimeDays: 7, shipsFrom: "us" },
        ];
    }
}
