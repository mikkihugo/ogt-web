import type { MedusaRequest, MedusaResponse } from "@medusajs/medusa";
import { OpsDb } from "../../modules/ops/service";

export async function GET(req: MedusaRequest, res: MedusaResponse) {
    const token = req.headers["x-internal-token"];
    if (!token || token !== process.env.INTERNAL_API_TOKEN) {
        return res.status(401).json({ error: "unauthorized" });
    }

    const shopId = req.query.shop_id as string;
    const ops = OpsDb.getInstance();
    const shop = await ops.getShopById(shopId);
    if (!shop) return res.status(404).json({ error: "shop not found" });

    return res.json({
        id: shop.id,
        name: shop.name,
        shop_type: shop.shop_type,
        default_region: shop.default_region,
        currency_code: shop.currency_code,
        default_locale: shop.default_locale,
        theme_tokens: shop.theme_tokens,
        marketing_config: shop.marketing_config,
        support_config: shop.support_config,
        catalog_rules: shop.catalog_rules,
        pricing_rules: shop.pricing_rules,
    });
}
