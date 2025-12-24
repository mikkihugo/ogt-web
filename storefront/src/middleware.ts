import { defineMiddleware } from 'astro:middleware';
import { DOMAIN_CONFIG } from './config/domains';

export const onRequest = defineMiddleware(async (context, next) => {
    const { request, locals } = context;

    // Get hostname from headers (handling proxies if needed)
    const host = request.headers.get('host') || 'localhost:4321';

    // Normalize host (remove port if needed only for lookup if strict matching isn't required)
    // But our config includes ports for localhost, so we keep it as is.
    let startConfig = DOMAIN_CONFIG[host];

    // Fallback if not found
    if (!startConfig) {
        startConfig = DOMAIN_CONFIG['default'];
    }

    // Inject into locals
    context.locals.salesChannelIds = startConfig.salesChannelIds;
    context.locals.locale = startConfig.locale;
    context.locals.region = startConfig.region;
    context.locals.theme = startConfig.theme;
    context.locals.currencyCode = startConfig.defaultCurrency;

    return next();
});
