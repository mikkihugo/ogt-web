import { Pool } from "pg";

export class OpsDb {
    private pool: Pool;
    private static instance: OpsDb;

    constructor() {
        this.pool = new Pool({ connectionString: process.env.OPS_DATABASE_URL });
    }

    static getInstance(): OpsDb {
        if (!OpsDb.instance) {
            OpsDb.instance = new OpsDb();
        }
        return OpsDb.instance;
    }

    async getShopByHost(host: string) {
        const q = `
      SELECT s.* FROM ops.shop_domain d
      JOIN ops.shop s ON s.id = d.shop_id
      WHERE d.domain = $1 AND s.status != 'disabled'
      LIMIT 1
    `;
        const { rows } = await this.pool.query(q, [host]);
        return rows[0] || null;
    }

    async getShopById(id: string) {
        const { rows } = await this.pool.query(`SELECT * FROM ops.shop WHERE id = $1`, [id]);
        return rows[0] || null;
    }

    async listShops() {
        const { rows } = await this.pool.query(`SELECT * FROM ops.shop ORDER BY name`);
        return rows;
    }

    async getQueryRunner() {
        return this.pool;
    }
}
