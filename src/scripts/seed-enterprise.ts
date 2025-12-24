import { ExecArgs } from "@medusajs/framework/types"
import { ContainerRegistrationKeys, Modules } from "@medusajs/framework/utils"
import {
    createSalesChannelsWorkflow,
    createRegionsWorkflow,
    linkSalesChannelsToApiKeyWorkflow,
    linkSalesChannelsToStockLocationWorkflow,
    createApiKeysWorkflow,
    updateStoresWorkflow
} from "@medusajs/medusa/core-flows"

export default async function seedEnterprise({ container }: ExecArgs) {
    const logger = container.resolve(ContainerRegistrationKeys.LOGGER)
    const storeModuleService = container.resolve(Modules.STORE)
    const salesChannelModuleService = container.resolve(Modules.SALES_CHANNEL)

    logger.info("Seeding Enterprise Data (Multi-Store)...")

    // 1. Get Default Store
    const [store] = await storeModuleService.listStores()

    // 2. Create Sales Channels
    const { result: scResult } = await createSalesChannelsWorkflow(container).run({
        input: {
            salesChannelsData: [
                { name: "US Store", description: "United States Storefront" },
                { name: "EU Store", description: "European Union Storefront" }
            ]
        }
    })

    const usChannel = scResult.find(sc => sc.name === "US Store")
    const euChannel = scResult.find(sc => sc.name === "EU Store")

    if (!usChannel || !euChannel) throw new Error("Failed to create channels")

    logger.info(`Created Sales Channels: ${usChannel.id} (US), ${euChannel.id} (EU)`)

    // 3. Create Regions
    // We'll reuse existing Europe region for EU, create NA for US
    const { result: regionResult } = await createRegionsWorkflow(container).run({
        input: {
            regions: [
                {
                    name: "North America",
                    currency_code: "usd",
                    countries: ["us", "ca"],
                    payment_providers: ["pp_system_default"],
                }
            ]
        }
    })

    logger.info("Created North America Region")

    // 4. Create/Link Publishable Keys
    // We will create one key that has access to BOTH, and handle filter in middleware? 
    // OR create distinct keys? 
    // For simplicity in this demo, let's Link the existing "Webshop" key to BOTH.

    // Find existing key
    const apiKeys = await container.resolve(Modules.API_KEY).listApiKeys({ title: "Webshop" })
    let webshopKey = apiKeys[0]

    if (webshopKey) {
        await linkSalesChannelsToApiKeyWorkflow(container).run({
            input: {
                id: webshopKey.id,
                add: [usChannel.id, euChannel.id]
            }
        })
        logger.info("Linked Webshop Key to US and EU Channels")
    }

    // 5. Link to Default Stock Location (Shared Inventory)
    // Retrieve the default stock location (created in initial seed)
    const stockLocationService = container.resolve(Modules.STOCK_LOCATION)
    const [stockLocation] = await stockLocationService.listStockLocations()

    if (stockLocation) {
        await linkSalesChannelsToStockLocationWorkflow(container).run({
            input: {
                id: stockLocation.id,
                add: [usChannel.id, euChannel.id]
            }
        })
        logger.info("Linked Channels to Shared Stock Location")
    }

    logger.info("Enterprise Seeding Completed.")
}
