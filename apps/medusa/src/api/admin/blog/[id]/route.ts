import { MedusaRequest, MedusaResponse } from "@medusajs/framework/http";
import { BLOG_MODULE } from "../../../../modules/blog";
import BlogModuleService from "../../../../modules/blog/service";

export const GET = async (req: MedusaRequest, res: MedusaResponse) => {
  const blogModuleService: BlogModuleService = req.scope.resolve(BLOG_MODULE);
  const id = req.params.id;

  const post = await blogModuleService.retrievePost(id);

  res.json({ post });
};

export const POST = async (req: MedusaRequest, res: MedusaResponse) => {
  const blogModuleService: BlogModuleService = req.scope.resolve(BLOG_MODULE);
  const id = req.params.id;

  const [post] = await blogModuleService.updatePosts([
    { id, ...(req.body as Record<string, any>) },
  ]);

  res.json({ post });
};

export const DELETE = async (req: MedusaRequest, res: MedusaResponse) => {
  const blogModuleService: BlogModuleService = req.scope.resolve(BLOG_MODULE);
  const id = req.params.id;

  await blogModuleService.deletePosts([id]);

  res.json({
    id,
    object: "post",
    deleted: true,
  });
};
