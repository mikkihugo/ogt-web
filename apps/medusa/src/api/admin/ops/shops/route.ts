import type { MedusaRequest, MedusaResponse } from "@medusajs/medusa";
import { OpsDb } from "../../modules/ops/service";

export async function GET(req: MedusaRequest, res: MedusaResponse) {
    const ops = OpsDb.getInstance();
    const shops = await ops.listShops();
    res.json({ shops });
}

export async function POST(req: MedusaRequest, res: MedusaResponse) {
    const {
        id, name, shop_type, default_region, currency_code, default_locale,
        theme_config, marketing_config, domains
    } = req.body as any;

    if (!id || !name || !default_region) {
        return res.status(400).json({ error: "Missing required fields" });
    }

    const ops = OpsDb.getInstance();
    const runner = await ops.getQueryRunner();

    try {
        await runner.query('BEGIN');

        // 1. Upsert Shop
        const qShop = `
            INSERT INTO ops.shop (
                id, name, shop_type, default_region, currency_code, default_locale, 
                theme_config, marketing_config
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                shop_type = EXCLUDED.shop_type,
                theme_config = EXCLUDED.theme_config,
                marketing_config = EXCLUDED.marketing_config,
                updated_at = now();
        `;
        await runner.query(qShop, [
            id, name, shop_type || 'store', default_region, currency_code || 'USD', default_locale || 'en',
            JSON.stringify(theme_config || {}), JSON.stringify(marketing_config || {})
        ]);

        // 2. Update Domains (Replace Strategy)
        if (Array.isArray(domains)) {
            // Delete old domains for this shop
            await runner.query(`DELETE FROM ops.shop_domain WHERE shop_id = $1`, [id]);

            // Insert new
            for (const d of domains) {
                await runner.query(
                    `INSERT INTO ops.shop_domain (domain, shop_id, is_primary) VALUES ($1, $2, $3)`,
                    [d.domain, id, !!d.is_primary]
                );
            }
        }

        await runner.query('COMMIT');
        res.json({ success: true, id });
    } catch (e: any) {
        await runner.query('ROLLBACK');
        res.status(500).json({ error: e.message });
    }
}
