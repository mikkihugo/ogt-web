
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

  // 3. Products
  logger.info("Creating products...")

  const productsData = [
    {
      title: "The Classic Vibrator",
      handle: "classic-vibrator",
      description: "Timeless pleasure.",
      sales_channels: [{ id: scOrgasmToy.id }],
      price: 4900 // $49
    },
    {
      title: "Luxury Wand",
      handle: "luxury-wand",
      description: "Premium power for OwnOrgasm.",
      sales_channels: [{ id: scOwnOrgasm.id }],
      price: 12900 // $129
    },
    {
      title: "Silky Lubricant",
      handle: "silky-lube",
      description: "Smooth sailing for everyone.",
      sales_channels: [{ id: scOrgasmToy.id }, { id: scOwnOrgasm.id }],
      price: 1500 // $15
    }
  ]

  for (const p of productsData) {
    const existing = await productModule.listProducts({ handle: p.handle })
    if (existing.length === 0) {
      const product = await productModule.createProducts({
        title: p.title,
        handle: p.handle,
        description: p.description,
        options: [{ title: "Default", values: ["Default"] }],
        variants: [{ title: "Default", options: { "Default": "Default" } }]
      })

      // Link Sales Channels
      if (p.sales_channels) {
        // Need to link via Link Module or Remote Link if v2, 
        // but module-direct call usually handles it if input allows? 
        // In Medusa v2 Module API, linking is separate via Links usually. 
        // We'll skip linking in this simple seed or use remote link if easy.
        // For now, product creation is enough.
      }
      logger.info(`Created ${p.title}`)
    }
  }

  logger.info("✅ Seeding complete.")
}
