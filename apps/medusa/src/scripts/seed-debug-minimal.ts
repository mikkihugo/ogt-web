import { ExecArgs } from "@medusajs/framework/types";
import { BLOG_MODULE } from "../modules/blog";
import BlogModuleService from "../modules/blog/service";

export default async function seedDebugMinimal({ container }: ExecArgs) {
  const blogModuleService: BlogModuleService = container.resolve(BLOG_MODULE);

  console.log("Debugging Blog minimal creation...");

  try {
    // Minimal test
    const post = await blogModuleService.createPosts({
      title: "Debug Post",
      slug: "debug-post-" + Date.now(),
      content: "Content",
      excerpt: "Excerpt",
      // Omit sales_channels and language_code
    });
    console.log("Success minimal:", post.id);
  } catch (e) {
    console.error("Failed minimal:", e);
  }

  try {
    // Test with sales_channels
    const post = await blogModuleService.createPosts({
      title: "Debug Post JSON",
      slug: "debug-post-json-" + Date.now(),
      content: "Content",
      channel_config: { ids: ["test"] } as any,
      language_code: "en-US",
    });
    console.log("Success JSON:", post.id);
  } catch (e) {
    console.error("Failed JSON:", e);
  }
}
