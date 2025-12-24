// Map your domains to Sales Channels and Locales
export const DOMAIN_CONFIG = {
    'localhost:4321': {
        salesChannelIds: ['sc_01KD5MXY8ZRNS0HTW40Z8GS3V3'], // US Store
        locale: 'en-US',
        region: 'us',
        theme: 'theme-lux',
        defaultCurrency: 'usd'
    },
    '127.0.0.1:4321': {
        salesChannelIds: ['sc_01KD5MXY8ZRNS0HTW40Z8GS3V3'], // US Store
        locale: 'en-US',
        region: 'us',
        theme: 'theme-lux',
        defaultCurrency: 'usd'
    },
    'us.orgasmtoy.com': {
        salesChannelIds: ['sc_01KD5MXY8ZRNS0HTW40Z8GS3V3'], // US Store
        locale: 'en-US',
        region: 'us',
        theme: 'theme-lux',
        defaultCurrency: 'usd'
    },
    'eu.orgasmtoy.com': {
        salesChannelIds: ['sc_01KD5MXY8ZGCBPB9ZCZ6KBNSQM'], // EU Store
        locale: 'en-IE', // Generic EU English
        region: 'eu',
        theme: 'theme-minimal',
        defaultCurrency: 'eur'
    },
    'ownorgasm.com': {
        salesChannelIds: ['sc_01KD5VZDZBHRPMJWQ599AFWSGK'], // OwnOrgasm Sales Channel
        locale: 'en-US',
        region: 'us',
        theme: 'theme-blog', // Assuming a specific theme might be needed, or default to lux
        defaultCurrency: 'usd'
    },
    // Default fallback (e.g. for unknown domains)
    'default': {
        salesChannelIds: ['sc_01KD5MXY8ZRNS0HTW40Z8GS3V3'], // Default to US
        locale: 'en-US',
        region: 'us',
        theme: 'theme-lux',
        defaultCurrency: 'usd'
    }
};
