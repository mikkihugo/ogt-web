import { SubscriberArgs, SubscriberConfig } from "@medusajs/medusa";
import { OrderRoutingService } from "../modules/dropship/order-routing.service";
import { Logger } from "@medusajs/types";

export default async function orderPlacedHandler({
    event,
    container,
}: SubscriberArgs<{ id: string }>) {
    const logger = container.resolve("logger") as Logger;
    const routingService = OrderRoutingService.getInstance();
    routingService.setLogger(logger);

    logger.info(`[Dropship] Handling Order Placed: ${event.data.id}`);

    // Resolve Order Service to get details
    // Medusa v2: Use RemoteQuery or Module Service
    // For now, assuming we can fetch basic order details or use a mocked fetch since 
    // we effectively only need Line Items + Shop Context

    // MOCK FETCH for Blueprint Verification (avoiding complex Remote Query setup in this shell)
    // In production: const order = await orderService.retrieve(event.data.id, { relations: ["items"] });
    const mockOrder = {
        id: event.data.id,
        shop_id: "shop_us", // Should come from order metadata or sales channel
        items: [
            { id: "item_1", variant_id: "variant_123", quantity: 1, unit_price: 1000 }
        ]
    };

    logger.info(`[Dropship] Routing ${mockOrder.items.length} items for Order ${mockOrder.id}`);

    await routingService.routeOrder(
        mockOrder.id,
        mockOrder.items,
        mockOrder.shop_id
    );
}

export const config: SubscriberConfig = {
    event: "order.placed",
};
