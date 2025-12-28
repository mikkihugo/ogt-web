
import { Modules } from "@medusajs/framework/utils"
import { ExecArgs } from "@medusajs/framework/types"
import {
  ContainerRegistrationKeys,
  MedusaContainer
} from "@medusajs/framework"

export default async function seedDemo(container: MedusaContainer, args: ExecArgs) {
  const logger = container.resolve(ContainerRegistrationKeys.LOGGER)
  const salesChannelModule = container.resolve(Modules.SALES_CHANNEL)
  const productModule = container.resolve(Modules.PRODUCT)
  const pricingModule = container.resolve(Modules.PRICING)
  const regionModule = container.resolve(Modules.REGION)
  const taxModule = container.resolve(Modules.TAX)
  const fulfillmentModule = container.resolve(Modules.FULFILLMENT)
  const apiCmsModule = container.resolve(Modules.API_KEY)

  logger.info("🌱 Seeding production data for OGT Web...")

  // 1. Sales Channels
  const [channels, count] = await salesChannelModule.listAndCountSalesChannels()
  let scOrgasmToy = channels.find(sc => sc.name === "OrgasmToy") || channels.find(sc => sc.name === "Default Sales Channel")
  let scOwnOrgasm = channels.find(sc => sc.name === "OwnOrgasm")

  if (!scOrgasmToy) {
    scOrgasmToy = await salesChannelModule.createSalesChannels({
      name: "OrgasmToy",
      description: "Main store for OrgasmToy brand"
    })
  } else if (scOrgasmToy.name !== "OrgasmToy") {
    await salesChannelModule.updateSalesChannels(scOrgasmToy.id, { name: "OrgasmToy" })
  }

  if (!scOwnOrgasm) {
    scOwnOrgasm = await salesChannelModule.createSalesChannels({
      name: "OwnOrgasm",
      description: "Premium brand OwnOrgasm"
    })
  }

  // 2. Regions (Global USD)
  const [regions] = await regionModule.listRegions()
  let region = regions[0]
  if (!region) {
    region = await regionModule.createRegions({
      name: "Global",
      currency_code: "usd",
      countries: ["us", "gb", "de", "fr"]
    })
  }

  const fileModule = container.resolve(Modules.FILE)

  // 3. Products
  logger.info("Creating products with images...")

  const productsData = [
    {
      title: "The Classic Vibrator",
      handle: "classic-vibrator",
      description: "Timeless pleasure.",
      sales_channels: [{ id: scOrgasmToy.id }],
      price: 4900,
      image: "https://dummyimage.com/600x400/000/fff&text=Vibrator"
    },
    {
      title: "Luxury Wand",
      handle: "luxury-wand",
      description: "Premium power for OwnOrgasm.",
      sales_channels: [{ id: scOwnOrgasm.id }],
      price: 12900,
      image: "https://dummyimage.com/600x400/000/fff&text=Luxury+Wand"
    },
    {
      title: "Silky Lubricant",
      handle: "silky-lube",
      description: "Smooth sailing for everyone.",
      sales_channels: [{ id: scOrgasmToy.id }, { id: scOwnOrgasm.id }],
      price: 1500,
      image: "https://dummyimage.com/600x400/000/fff&text=Lube"
    }
  ]

  for (const p of productsData) {
    const existing = await productModule.listProducts({ handle: p.handle })
    if (existing.length === 0) {
      // Upload Image
      let images = []
      try {
        const response = await fetch(p.image)
        const blob = await response.blob()
        const arrayBuffer = await blob.arrayBuffer()
        const buffer = Buffer.from(arrayBuffer)

        const file = await fileModule.createFiles({
          files: [{
            filename: `${p.handle}.png`,
            mimeType: "image/png",
            content: buffer.toString("base64"), // File module might expect base64 or buffer depending on provider
            // Medusa v2 File Module usually expects object with filename and content string (base64) for createFiles?
            // Actually, the main create method takes specific provider input.
            // Let's us the standard service method if available, or just generic input.
            // Checking type: CreateFileDTO... content is string.
          }]
        })
        images = file.map(f => f.url)
      } catch (e) {
        logger.warn(`Failed to upload image for ${p.title}: ${e.message}`)
      }

      const product = await productModule.createProducts({
        title: p.title,
        handle: p.handle,
        description: p.description,
        options: [{ title: "Default", values: ["Default"] }],
        variants: [{ title: "Default", options: { "Default": "Default" } }],
        images: images.map(url => ({ url })),
        thumbnail: images[0]
      })

      logger.info(`Created ${p.title} with image`)
    }
  }

  logger.info("✅ Seeding complete.")
}
```
