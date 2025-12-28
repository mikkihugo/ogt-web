import { ExecArgs } from "@medusajs/framework/types";
import { Modules } from "@medusajs/framework/utils";
import { ApiKeyType } from "@medusajs/framework/utils";

export default async function createTestApiKey({ container }: ExecArgs) {
  const apiKeyService = container.resolve(Modules.API_KEY);
  const salesChannelService = container.resolve(Modules.SALES_CHANNEL);

  const [usChannel] = await salesChannelService.listSalesChannels({
    name: "US Store",
  });
  const [euChannel] = await salesChannelService.listSalesChannels({
    name: "EU Store",
  });

  if (!usChannel || !euChannel) {
    throw new Error("Sales channels not found");
  }

  const key = await apiKeyService.createApiKeys({
    title: "Test Key",
    type: ApiKeyType.PUBLISHABLE,
    created_by: "test",
  });

  const remoteLink = container.resolve("remoteLink");

  await remoteLink.create([
    {
      [Modules.API_KEY]: {
        publishable_key_id: key.id,
      },
      [Modules.SALES_CHANNEL]: {
        sales_channel_id: usChannel.id,
      },
    },
    {
      [Modules.API_KEY]: {
        publishable_key_id: key.id,
      },
      [Modules.SALES_CHANNEL]: {
        sales_channel_id: euChannel.id,
      },
    },
  ]);

  console.log(`Created Publishable API Key: ${key.token}`);
}
