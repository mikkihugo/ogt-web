import { ExecArgs } from "@medusajs/framework/types"
import { BLOG_MODULE } from "../modules/blog"
import BlogModuleService from "../modules/blog/service"

export default async function seedBlog({ container }: ExecArgs) {
    const blogModuleService: BlogModuleService = container.resolve(BLOG_MODULE)

    console.log("Seeding blog posts...")

    const posts = [
        {
            title: "Welcome to OGT",
            slug: "welcome-to-ogt",
            excerpt: "Discover the mission and values of OGT Store, your destination for premium wellness and pleasure products.",
            content: "Welcome to OGT Store, your destination for premium wellness and pleasure products.\n\n## Our Mission\n\nWe believe that everyone deserves access to high-quality, body-safe products that enhance their intimate wellness journey. Our carefully curated collection features only the best products from trusted manufacturers.",
            category: "news",
            published_at: new Date(),
        },
        {
            title: "Wellness Tips for 2024",
            slug: "wellness-tips-2024",
            excerpt: "Start your year right with our top wellness tips for a better intimate life.",
            content: "As we move into 2024, it's important to prioritize self-care and intimate wellness...",
            category: "guides",
            published_at: new Date(),
        }
    ]

    for (const post of posts) {
        await blogModuleService.createPosts(post)
        console.log(`Created post: ${post.title}`)
    }

    console.log("Blog seeding completed.")
}
