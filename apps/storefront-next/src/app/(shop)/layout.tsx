import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { headers } from "next/headers";
import { ChatwootLoader } from "../../lib/chatwoot";
import { TrackingLoader } from "../../lib/tracking";
// import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
    title: "Unified Shop",
    description: "Powered by OGT-Web",
};

export default async function RootLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const h = headers();
    const shopId = h.get("x-shop-id") || "";

    let shop = { default_locale: "en", marketing_config: {}, support_config: {} };

    try {
        const res = await fetch(`${process.env.SHOP_RESOLVER_URL}/store/shop-config?shop_id=${shopId}`, {
            headers: { "x-internal-token": process.env.INTERNAL_API_TOKEN || "" },
            cache: "no-store",
        });
        if (res.ok) {
            shop = await res.json();
        }
    } catch (e) {
        console.error("Failed to load shop config", e);
    }

    return (
        <html lang={shop.default_locale}>
            <body className={inter.className}>
                <TrackingLoader config={shop.marketing_config} />
                <ChatwootLoader config={shop.support_config} />
                {children}
            </body>
        </html>
    );
}
