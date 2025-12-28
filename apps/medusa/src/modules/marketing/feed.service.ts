import { Logger } from "@medusajs/types";
import { OpsDb } from "../ops/service";

// Simple XML builder helper
const escapeXml = (unsafe: string) => {
    return unsafe.replace(/[<>&'"]/g, (c) => {
        switch (c) {
            case '<': return '&lt;';
            case '>': return '&gt;';
            case '&': return '&amp;';
            case '\'': return '&apos;';
            case '"': return '&quot;';
        }
        return c;
    });
};

export class FeedService {
    private ops: OpsDb;
    private logger?: Logger;
    private static instance: FeedService;

    constructor() {
        this.ops = OpsDb.getInstance();
    }

    static getInstance(): FeedService {
        if (!FeedService.instance) {
            FeedService.instance = new FeedService();
        }
        return FeedService.instance;
    }

    setLogger(logger: Logger) {
        this.logger = logger;
    }

    /**
     * Generates a Google Merchant Center XML feed
     * @param shopId The specific shop to generate for (controls pricing/filtering)
     */
    async generateGoogleFeed(shopId: string, baseUrl: string): Promise<string> {
        this.logger?.info(`Generating Google Feed for shop: ${shopId}`);

        // 1. Fetch Products
        // In a real app, we'd join with Medusa Product tables.
        // For Blueprint, we'll fetch from our "SkuMap" + "Inventory" to simulate "Offers"
        // This effectively creates a feed of everything we have dropship access to.

        const q = `
            SELECT 
                s.name as supplier_name,
                sm.supplier_sku,
                sm.medusa_variant_id,
                si.cost,
                si.currency_code
            FROM dropship.sku_map sm
            JOIN dropship.supplier_inventory si 
                ON sm.supplier_id = si.supplier_id 
                AND sm.supplier_sku = si.supplier_sku
            JOIN dropship.supplier s ON s.id = sm.supplier_id
            -- Phase 8.2: Join Product Metrics to exclude suppressed items
            LEFT JOIN dropship.product_metrics pm ON pm.medusa_product_id = sm.medusa_variant_id
            WHERE si.qty > 0 
              AND (pm.suppressed IS NULL OR pm.suppressed = FALSE)
        `;

        const { rows } = await this.ops.getQueryRunner().then(pool => pool.query(q));

        let xml = `<?xml version="1.0"?>
<rss xmlns:g="http://base.google.com/ns/1.0" version="2.0">
<channel>
<title>Shop Feed - ${escapeXml(shopId)}</title>
<link>${escapeXml(baseUrl)}</link>
<description>Product Feed</description>
`;

        for (const row of rows) {
            // Logic: Apply pricing policy 
            // Mock Policy: Price = Cost * 1.5
            const price = (parseFloat(row.cost) * 1.5).toFixed(2);

            // Mock: Basic Metadata usually from Medusa Product
            const title = `Product ${row.medusa_variant_id}`;
            const link = `${baseUrl}/products/${row.medusa_variant_id}`;
            const imageLink = `${baseUrl}/images/${row.medusa_variant_id}.jpg`;

            xml += `<item>
<g:id>${escapeXml(row.medusa_variant_id)}</g:id>
<g:title>${escapeXml(title)}</g:title>
<g:description>Best product from ${escapeXml(row.supplier_name)}</g:description>
<g:link>${escapeXml(link)}</g:link>
<g:image_link>${escapeXml(imageLink)}</g:image_link>
<g:condition>new</g:condition>
<g:availability>in stock</g:availability>
<g:price>${price} ${row.currency_code}</g:price>
<g:brand>${escapeXml(row.supplier_name)}</g:brand>
</item>
`;
        }

        xml += `</channel>
</rss>`;

        return xml;
    }
}
