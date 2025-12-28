import type { AuthenticatedMedusaRequest, MedusaResponse } from "@medusajs/framework";
import { OpsDb } from "../../../modules/ops/service";

export async function GET(req: AuthenticatedMedusaRequest, res: MedusaResponse) {
  const token = req.headers["x-internal-token"];
  if (!token || token !== process.env.INTERNAL_API_TOKEN) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const host = (req.query.host as string)?.toLowerCase();
  const shopId = req.query.shop_id as string;

  if (!host && !shopId)
    return res.status(400).json({ error: "missing host or shop_id" });

  const ops = OpsDb.getInstance();
  let shop;

  if (shopId) {
    shop = await ops.getShopById(shopId);
  } else {
    shop = await ops.getShopByHost(host);
  }
  if (!shop) return res.status(404).json({ error: "shop not found" });

  return res.json({
    id: shop.id,
    shop_type: shop.shop_type,
    default_region: shop.default_region,
    currency_code: shop.currency_code,
    default_locale: shop.default_locale,
    // Configs
    theme_config: shop.theme_config,
    navigation_config: shop.navigation_config,
    legal_config: shop.legal_config,
    seo_config: shop.seo_config,
    payment_config: shop.payment_config,
    marketing_config: shop.marketing_config,
    support_config: shop.support_config,
  });
}
