"use client";

import { useEffect } from "react";

export function ChatwootLoader({ config }: { config: any }) {
    useEffect(() => {
        if (!config?.chatwoot_base_url || !config?.chatwoot_website_token) return;

        (function (d, t) {
            const g = d.createElement(t) as HTMLScriptElement;
            const s = d.getElementsByTagName(t)[0];
            // @ts-ignore
            g.src = `${config.chatwoot_base_url}/packs/js/sdk.js`;
            g.async = true;
            g.onload = function () {
                // @ts-ignore
                window.chatwootSDK?.run({
                    websiteToken: config.chatwoot_website_token,
                    baseUrl: config.chatwoot_base_url,
                });
            };
            s.parentNode?.insertBefore(g, s);
        })(document, "script");
    }, [config]);

    return null;
}
