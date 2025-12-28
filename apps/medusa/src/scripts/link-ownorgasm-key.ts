import { ExecArgs } from "@medusajs/framework/types";
import { Modules } from "@medusajs/framework/utils";

export default async function linkKeyToOwnOrgasm({ container }: ExecArgs) {
  const logger = container.resolve("logger");
  const salesChannelService = container.resolve(Modules.SALES_CHANNEL);
  const apiKeyService = container.resolve(Modules.API_KEY);
  const remoteLink = container.resolve("remoteLink");

  // 1. Get OwnOrgasm Channel
  const [channel] = await salesChannelService.listSalesChannels({
    name: "OwnOrgasm",
  });
  if (!channel) {
    throw new Error("OwnOrgasm channel not found");
  }

  // 2. Get the Publishable Key used in Storefront (we know the token from env or can find by title/type)
  // We'll search for the one we created "Test Key" or just list all publishable and link to all for safety in dev
  const apiKeys = await apiKeyService.listApiKeys({ type: "publishable" });

  for (const key of apiKeys) {
    logger.info(
      `Linking key ${key.id} (${key.title}) to OwnOrgasm channel ${channel.id}...`,
    );
    await remoteLink.create([
      {
        [Modules.API_KEY]: { publishable_key_id: key.id },
        [Modules.SALES_CHANNEL]: { sales_channel_id: channel.id },
      },
    ]);
  }

  logger.info("Done linking keys.");
}
