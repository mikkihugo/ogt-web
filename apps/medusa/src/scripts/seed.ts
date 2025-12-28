import { ContainerRegistrationKeys, Modules } from "@medusajs/framework/utils";
import { ExecArgs } from "@medusajs/framework/types";
import { MedusaContainer } from "@medusajs/framework";

export default async function seedDemo(
  container: MedusaContainer,
  args: ExecArgs,
) {
  const logger = container.resolve(ContainerRegistrationKeys.LOGGER);
  const salesChannelModule = container.resolve(Modules.SALES_CHANNEL);
  const productModule = container.resolve(Modules.PRODUCT);
  const pricingModule = container.resolve(Modules.PRICING);
  const regionModule = container.resolve(Modules.REGION);
  const taxModule = container.resolve(Modules.TAX);
  const fulfillmentModule = container.resolve(Modules.FULFILLMENT);
  const apiCmsModule = container.resolve(Modules.API_KEY);

  logger.info("🌱 Seeding production data for OGT Web...");

  // 1. Sales Channels
  const [channels, count] =
    await salesChannelModule.listAndCountSalesChannels();
  let scOrgasmToy =
    channels.find((sc) => sc.name === "OrgasmToy") ||
    channels.find((sc) => sc.name === "Default Sales Channel");
  let scOwnOrgasm = channels.find((sc) => sc.name === "OwnOrgasm");

  if (!scOrgasmToy) {
    scOrgasmToy = await salesChannelModule.createSalesChannels({
      name: "OrgasmToy",
      description: "Main store for OrgasmToy brand",
    });
  } else if (scOrgasmToy.name !== "OrgasmToy") {
    await salesChannelModule.updateSalesChannels(scOrgasmToy.id, {
      name: "OrgasmToy",
    });
  }

  if (!scOwnOrgasm) {
    scOwnOrgasm = await salesChannelModule.createSalesChannels({
      name: "OwnOrgasm",
      description: "Premium brand OwnOrgasm",
    });
  }

  // 2. Regions (Global USD)
  const [regions] = await regionModule.listRegions();
  let region = (regions as any)[0];
  if (!region) {
    region = await regionModule.createRegions({
      name: "Global",
      currency_code: "usd",
      countries: ["us", "gb", "de", "fr"],
    });
  }

  const fileModule = container.resolve(Modules.FILE);

  // 3. Products
  logger.info("Creating products with images...");

  const productsData = [
    {
      title: "The Classic Vibrator",
      handle: "classic-vibrator",
      description: "Timeless pleasure.",
      sales_channels: [{ id: scOrgasmToy.id }],
      price: 4900,
      image: "https://picsum.photos/seed/plant1/600/400",
    },
    {
      title: "Luxury Wand",
      handle: "luxury-wand",
      description: "Premium power for OwnOrgasm.",
      sales_channels: [{ id: scOwnOrgasm.id }],
      price: 12900,
      image: "https://picsum.photos/seed/flower2/600/400",
    },
    {
      title: "Silky Lubricant",
      handle: "silky-lube",
      description: "Smooth sailing for everyone.",
      sales_channels: [{ id: scOrgasmToy.id }, { id: scOwnOrgasm.id }],
      price: 1500,
      image: "https://picsum.photos/seed/leaf3/600/400",
    },
  ];

  for (const p of productsData) {
    const existing = await productModule.listProducts({ handle: p.handle });
    if (existing.length === 0) {
      // Upload Image
      let images: string[] = [];
      try {
        const response = await fetch(p.image);
        const blob = await response.blob();
        const arrayBuffer = await blob.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        const file = await fileModule.createFiles([
          {
            filename: `${p.handle}.png`,
            mimeType: "image/png",
            content: buffer.toString("base64"),
          },
        ]);
        images = file.map((f) => f.url);
      } catch (e) {
        const err = e as Error
        logger.warn(`Failed to upload image for ${p.title}: ${err.message}`);
      }

      const product = await productModule.createProducts({
        title: p.title,
        handle: p.handle,
        description: p.description,
        options: [{ title: "Default", values: ["Default"] }],
        variants: [{ title: "Default", options: { Default: "Default" } }],
        images: images.map((url) => ({ url })),
        thumbnail: images[0],
      });

      logger.info(`Created ${p.title} with image`);

      // 4. Inventory (Critical for Checkout)
      const variant = product.variants[0];
      const inventoryModule = container.resolve(Modules.INVENTORY);
      const link = container.resolve(ContainerRegistrationKeys.REMOTE_LINK);
      const stockLocationModule = container.resolve(Modules.STOCK_LOCATION);

      const inventoryItem = await inventoryModule.createInventoryItems({
        sku: `${p.handle}-sku`,
        requires_shipping: true,
      });

      // Link Variant to Inventory Item
      // (In Medusa v2 this is via Remote Link or specific service, assuming standard link name)
      await link.create({
        productService: {
          variant_id: variant.id,
        },
        inventoryService: {
          inventory_item_id: inventoryItem.id,
        },
      });

      // Add Stock to default location (we need a location first? default usually exists or we create one)
      const [locations] = await stockLocationModule.listStockLocations({});
      let locationId = (locations as any)[0]?.id;

      if (!locationId) {
        const loc = await stockLocationModule.createStockLocations({
          name: "Default Warehouse",
        });
        locationId = loc.id;
        // Link Sales Channel to Stock Location (required for visibility)
        // Sales Channel -> Stock Location link
        await link.create({
          salesChannelService: {
            sales_channel_id: scOrgasmToy.id, // Link to both?
          },
          stockLocationService: {
            stock_location_id: locationId,
          },
        });
        await link.create({
          salesChannelService: {
            sales_channel_id: scOwnOrgasm.id,
          },
          stockLocationService: {
            stock_location_id: locationId,
          },
        });
      }

      await inventoryModule.createInventoryLevels({
        inventory_item_id: inventoryItem.id,
        location_id: locationId,
        stocked_quantity: 100,
      });
    }
  }

  // 5. Collections with Images (for Site Content)
  logger.info("Creating collections with images...");
  const collectionsData = [
    {
      title: "Summer Vibes",
      handle: "summer-vibes",
      image: "https://picsum.photos/seed/summer/800/300",
    },
    {
      title: "Essentials",
      handle: "essentials",
      image: "https://picsum.photos/seed/nature/800/300",
    },
  ];

  for (const c of collectionsData) {
    // Upload Image
    let imageUrl = "";
    try {
      const response = await fetch(c.image);
      const blob = await response.blob();
      const arrayBuffer = await blob.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);

      const file = await fileModule.createFiles([
        {
          filename: `${c.handle}-col.png`,
          mimeType: "image/png",
          content: buffer.toString("base64"),
        },
      ]);
      imageUrl = file[0].url;
    } catch (e) {
      const err = e as Error
      logger.warn(`Failed to upload image for collection ${c.title}: ${err.message}`);
    }

    await (productModule as any).createCollections({
      title: c.title,
      handle: c.handle,
      metadata: {
        image: imageUrl, // Storefront can read this
      },
    });
  }

  logger.info("✅ Seeding complete.");
}
