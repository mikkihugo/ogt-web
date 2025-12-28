"use client";
import { useEffect } from "react";

export function TrackingLoader({ config }: { config: any }) {
    useEffect(() => {
        // GA4
        const gaId = config?.ga4_measurement_id;
        if (gaId) {
            const s = document.createElement("script");
            s.async = true;
            s.src = `https://www.googletagmanager.com/gtag/js?id=${gaId}`;
            document.head.appendChild(s);

            const inline = document.createElement("script");
            inline.innerHTML = `
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', '${gaId}');
      `;
            document.head.appendChild(inline);
        }

        // Meta pixel (simplified)
        const pixelId = config?.meta_pixel_id;
        if (pixelId) {
            const inline = document.createElement("script");
            inline.innerHTML = `
        !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
        n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;
        n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;
        t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window, document,'script',
        'https://connect.facebook.net/en_US/fbevents.js');
        fbq('init', '${pixelId}');
        fbq('track', 'PageView');
      `;
            document.head.appendChild(inline);
        }
    }, [config]);

    return null;
}
