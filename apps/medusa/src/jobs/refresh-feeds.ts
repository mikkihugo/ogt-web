import { MedusaContainer } from "@medusajs/framework";
import { Logger } from "@medusajs/types";
import { FeedService } from "../modules/marketing/feed.service";
import * as fs from "fs";
import * as path from "path";

export default async function refreshFeedsJob(container: MedusaContainer) {
  const logger = container.resolve("logger") as Logger;
  const feedService = FeedService.getInstance();
  feedService.setLogger(logger);

  logger.info("Starting Feed Refresh Job...");

  try {
    // In a real multi-shop setup, we'd iterate over all active shops.
    // Mock Shop: 'shop_us'
    const shopId = "shop_us";
    const baseUrl = "https://shop-us.example.com";

    const xml = await feedService.generateGoogleFeed(shopId, baseUrl);

    // Write to public dir (mocking S3 upload)
    const publicDir = path.resolve(process.cwd(), "public/feeds");
    if (!fs.existsSync(publicDir)) {
      fs.mkdirSync(publicDir, { recursive: true });
    }

    const filePath = path.join(publicDir, `${shopId}_google_feed.xml`);
    fs.writeFileSync(filePath, xml);

    logger.info(`Feed generated successfully at: ${filePath}`);
  } catch (err) {
    logger.error("Product Scoring Failed", err as Error);
  }
}

export const config = {
  name: "refresh-feeds",
  schedule: "0 0 * * *",
};
