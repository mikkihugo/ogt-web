import { OpsDb } from "../ops/service";

export interface Supplier {
  id: string;
  name: string;
  status: "active" | "paused" | "inactive";
  base_url?: string;
  auth_type: "api_key" | "oauth" | "basic" | "custom";
  rate_limit_per_min: number;
}

export interface ShopSupplierPolicy {
  shop_id: string;
  supplier_id: string;
  buffer_stock: number;
  min_margin: number;
  enabled: boolean;
}

export class SupplierService {
  private ops: OpsDb;
  private static instance: SupplierService;

  constructor() {
    this.ops = OpsDb.getInstance();
  }

  static getInstance(): SupplierService {
    if (!SupplierService.instance) {
      SupplierService.instance = new SupplierService();
    }
    return SupplierService.instance;
  }

  async listActiveSuppliers(): Promise<Supplier[]> {
    const { rows } = await this.ops
      .getQueryRunner()
      .then((pool) =>
        pool.query(`SELECT * FROM dropship.supplier WHERE status = 'active'`),
      );
    return rows;
  }

  async getSupplier(id: string): Promise<Supplier | null> {
    const { rows } = await this.ops
      .getQueryRunner()
      .then((pool) =>
        pool.query(`SELECT * FROM dropship.supplier WHERE id = $1`, [id]),
      );
    return rows[0] || null;
  }

  async createSupplier(supplier: Supplier): Promise<Supplier> {
    const q = `
      INSERT INTO dropship.supplier (id, name, status, base_url, auth_type, rate_limit_per_min)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;
    const { rows } = await this.ops
      .getQueryRunner()
      .then((pool) =>
        pool.query(q, [
          supplier.id,
          supplier.name,
          supplier.status,
          supplier.base_url,
          supplier.auth_type,
          supplier.rate_limit_per_min,
        ]),
      );
    return rows[0];
  }

  async getPolicy(
    shopId: string,
    supplierId: string,
  ): Promise<ShopSupplierPolicy | null> {
    const { rows } = await this.ops
      .getQueryRunner()
      .then((pool) =>
        pool.query(
          `SELECT * FROM dropship.shop_supplier_policy WHERE shop_id = $1 AND supplier_id = $2`,
          [shopId, supplierId],
        ),
      );
    return rows[0] || null;
  }
}
