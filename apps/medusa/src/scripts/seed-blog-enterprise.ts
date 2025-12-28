import { ExecArgs } from "@medusajs/framework/types";
import { BLOG_MODULE } from "../modules/blog";
import BlogModuleService from "../modules/blog/service";
import { Modules } from "@medusajs/framework/utils";

export default async function seedBlogEnterprise({ container }: ExecArgs) {
  const blogModuleService: BlogModuleService = container.resolve(BLOG_MODULE);
  const salesChannelService = container.resolve(Modules.SALES_CHANNEL);

  console.log("Seeding Enterprise Blog Posts...");

  // Get Channels
  const [usChannel] = await salesChannelService.listSalesChannels({
    name: "US Store",
  });
  const [euChannel] = await salesChannelService.listSalesChannels({
    name: "EU Store",
  });

  if (!usChannel || !euChannel) {
    throw new Error("Sales channels not found. Run seed-enterprise first.");
  }

  const posts = [
    {
      title: "US Exclusive: 4th of July Wellness",
      slug: "us-exclusive-july",
      excerpt: "Tips for the holiday weekend.",
      content: "# US Content",
      category: "news",
      published_at: new Date(),
      channel_config: usChannel ? { ids: [usChannel.id] } : null,
      language_code: "en-US",
    },
    {
      title: "EU Exclusive: Summer in Paris",
      slug: "eu-exclusive-paris",
      excerpt: "Romantic guides for European summer.",
      content: "# EU Content",
      category: "guides",
      published_at: new Date(),
      channel_config: euChannel ? { ids: [euChannel.id] } : null,
      language_code: "en-IE",
    },
    {
      title: "Global: The Art of Intimacy",
      slug: "global-art-intimacy",
      excerpt: "A guide for everyone, everywhere.",
      content: "# Global Content",
      category: "wellness",
      published_at: new Date(),
      channel_config:
        usChannel && euChannel ? { ids: [usChannel.id, euChannel.id] } : null,
      language_code: "en-US",
    },
  ];

  for (const post of posts) {
    // Check if exists
    const existing = await blogModuleService.listPosts({ slug: post.slug });
    if (existing.length > 0) {
      console.log(`Update/Skip ${post.title}`);
      // ideally update
    } else {
      await blogModuleService.createPosts(post);
      console.log(`Created post: ${post.title}`);
    }
  }

  console.log("Enterprise Blog seeding completed.");
}
