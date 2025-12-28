import type { MedusaRequest, MedusaResponse } from "@medusajs/medusa";
import { OpsDb } from "../../modules/ops/service";

export async function GET(req: MedusaRequest, res: MedusaResponse) {
    const token = req.headers["x-internal-token"];
    if (!token || token !== process.env.INTERNAL_API_TOKEN) {
        return res.status(401).json({ error: "unauthorized" });
    }

    const host = (req.query.host as string)?.toLowerCase();
    if (!host) return res.status(400).json({ error: "missing host" });

    const ops = OpsDb.getInstance();
    const shop = await ops.getShopByHost(host);
    if (!shop) return res.status(404).json({ error: "shop not found" });

    return res.json({
        id: shop.id,
        shop_type: shop.shop_type,
        default_region: shop.default_region,
        currency_code: shop.currency_code,
        default_locale: shop.default_locale,
    });
}
