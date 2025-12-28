import { ExecArgs } from "@medusajs/framework/types"
import { ContainerRegistrationKeys, Modules } from "@medusajs/framework/utils"
import { BLOG_MODULE } from "../modules/blog/index.js"
import BlogModuleService from "../modules/blog/service.js"

export default async function seedOwnOrgasm({ container }: ExecArgs) {
    const logger = container.resolve(ContainerRegistrationKeys.LOGGER)
    const salesChannelService = container.resolve(Modules.SALES_CHANNEL)
    const blogModuleService: BlogModuleService = container.resolve(BLOG_MODULE)
    const apiKeyService = container.resolve(Modules.API_KEY)
    const remoteLink = container.resolve("remoteLink")

    logger.info("Seeding OwnOrgasm Channel...")

    // 1. Create Sales Channel
    let channel = await salesChannelService.listSalesChannels({ name: "OwnOrgasm" }).then(c => c[0])
    if (!channel) {
        channel = await salesChannelService.createSalesChannels({
            name: "OwnOrgasm",
            description: "Standalone channel for OwnOrgasm brand",
        })
        logger.info(`Created Sales Channel: OwnOrgasm (${channel.id})`)
    } else {
        logger.info(`Using existing Sales Channel: OwnOrgasm (${channel.id})`)
    }

    // 2. Add to API Key (if exists, or ensure we have one)
    // For simplicity, we'll attach it to the existing Pub Key if we can find it, or just log the ID for config
    const apiKeys = await apiKeyService.listApiKeys({ type: "publishable" })
    if (apiKeys.length > 0) {
        // Link to the first available pub key for testing convenience
        const key = apiKeys[0]
        await remoteLink.create([
            {
                [Modules.API_KEY]: { publishable_key_id: key.id },
                [Modules.SALES_CHANNEL]: { sales_channel_id: channel.id },
            },
        ])
        logger.info(`Linked OwnOrgasm channel to API Key: ${key.title}`)
    }

    // 3. Create Exclusive Post
    const postData = {
        title: "OwnOrgasm Exclusive: The Journey Begins",
        slug: "ownorgasm-journey-begins",
        excerpt: "Welcome to a new chapter of self-discovery.",
        content: "# Welcome to OwnOrgasm\n\nThis is the start of something special.",
        category: "wellness",
        published_at: new Date().toISOString(),
        channel_config: {
            ids: [channel.id]
        },
        language_code: "en-US"
    }

    const existing = await blogModuleService.listPosts({ slug: postData.slug })
    if (existing.length === 0) {
        await blogModuleService.createPosts(postData)
        logger.info(`Created post: ${postData.title}`)
    } else {
        logger.info(`Post already exists: ${postData.title}`)
        // Update to ensure channel config is correct
        await blogModuleService.updatePosts(existing[0].id, {
            channel_config: { ids: [channel.id] }
        })
        logger.info(`Updated channel config for: ${postData.title}`)
    }

    logger.info("------------------------------------------------")
    logger.info(`OwnOrgasm Sales Channel ID: ${channel.id}`)
    logger.info("------------------------------------------------")
}
