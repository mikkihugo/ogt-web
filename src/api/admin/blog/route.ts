import {
    MedusaRequest,
    MedusaResponse,
} from "@medusajs/framework/http"
import {
    ContainerRegistrationKeys,
    Modules
} from "@medusajs/framework/utils"
import { BLOG_MODULE } from "../../../modules/blog"
import BlogModuleService from "../../../modules/blog/service"

export const GET = async (
    req: MedusaRequest,
    res: MedusaResponse
) => {
    const blogModuleService: BlogModuleService = req.scope.resolve(BLOG_MODULE)

    // TODO: Add pagination support
    const [posts, count] = await blogModuleService.listAndCountPosts(
        {}, // Filters
        {
            order: { published_at: "DESC" },
        }
    )

    res.json({
        posts,
        count,
    })
}

export const POST = async (
    req: MedusaRequest,
    res: MedusaResponse
) => {
    const blogModuleService: BlogModuleService = req.scope.resolve(BLOG_MODULE)

    const post = await blogModuleService.createPosts(req.body)

    res.json({ post })
}
