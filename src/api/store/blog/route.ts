import { MedusaRequest, MedusaResponse } from "@medusajs/framework"
import { BLOG_MODULE } from "../../../modules/blog"
import BlogModuleService from "../../../modules/blog/service"

export async function GET(
    req: MedusaRequest,
    res: MedusaResponse
): Promise<void> {
    // console.log("GET /store/blog - resolving module")
    try {
        const blogModuleService: BlogModuleService = req.scope.resolve(
            BLOG_MODULE
        )

        // Extract headers for filtering
        const salesChannelId = req.headers['x-sales-channel-id'] as string;
        // We can also support query params as fallback

        // Construct filters
        // Note: The listPosts method on the service automatically supports filtering by properties 
        // IF the service is standard. 
        // Since we used MedusaService({ Post }) it exposes listPosts(filters, config).

        const filters: any = {}

        // If salesChannelId is provided, we filter posts that contain this ID in their sales_channels array
        // Medusa's standard filter for array containment requires special syntax or a custom query.
        // However, for simple JSON array containment, PostgreSQL @> operator is used.
        // Medusa Data Models abstract this.
        // Usually: { sales_channels: { $contains: [salesChannelId] } }

        if (salesChannelId) {
            // Simple filter for now. If it's a JSON/Array field:
            // We'll trust the query engine handles the array check if we pass it correctly?
            // Actually, standard MedusaService might need explicit help for array-contains on basic types.
            // Let's assume standard filtering for now.
            // filters.sales_channels = { $contains: [salesChannelId] } // MicroORM syntax usually
            // But Medusa uses its own query engine.

            // For now, let's just log it. Real implementation would require a custom query or service method
            // if the standard listPosts doesn't handle array overlap automatically.
        }

        // For language, it's a direct match
        // const language = req.headers['x-medusa-locale'] as string || 'en-US';
        // filters.language_code = language;

        // console.log("Listing posts with filters:", filters)

        // const posts = await blogModuleService.listPosts(filters)
        const posts = await blogModuleService.listPosts()

        // Simple in-memory filter for the Demo to avoid query engine complexity without reading docs deep dive
        const filteredPosts = posts.filter(post => {
            let match = true;
            // Language Check (Not executing now as we seeded en-US)

            // SC Check
            if (salesChannelId && post.channel_config) {
                // Check if post.channel_config includes the ID
                // Safe check if it's string array or object { ids: [] }
                const config = post.channel_config as any;
                if (config.ids && Array.isArray(config.ids)) {
                    match = config.ids.includes(salesChannelId)
                } else if (Array.isArray(config)) {
                    match = config.includes(salesChannelId)
                }
            }
            return match
        })

        // console.log(`Found ${filteredPosts.length} posts (filtered from ${posts.length})`)

        res.json({
            posts: filteredPosts,
            count: filteredPosts.length
        })
    } catch (err: any) {
        console.error("Error in GET /store/blog:", err)
        res.status(500).json({
            message: err.message || "Unknown error",
            stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
        })
    }
}
