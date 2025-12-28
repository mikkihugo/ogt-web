import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export async function middleware(req: NextRequest) {
    const host = req.headers.get("host")?.toLowerCase() || "";
    const url = req.nextUrl;

    // Call your Medusa admin API route that reads ops_db.shop_domain
    const res = await fetch(`${process.env.SHOP_RESOLVER_URL}/store/resolve-shop?host=${encodeURIComponent(host)}`, {
        headers: { "x-internal-token": process.env.INTERNAL_API_TOKEN || "" },
        cache: "no-store",
    });

    if (!res.ok) {
        // default: show maintenance or redirect
        return NextResponse.rewrite(new URL("/_system/no-shop", url));
    }

    const shop = await res.json();

    // Attach shop context as headers (server components can read)
    const requestHeaders = new Headers(req.headers);
    requestHeaders.set("x-shop-id", shop.id);
    requestHeaders.set("x-shop-type", shop.shop_type);
    requestHeaders.set("x-shop-region", shop.default_region);
    requestHeaders.set("x-shop-currency", shop.currency_code);
    requestHeaders.set("x-shop-locale", shop.default_locale);

    // Funnel shops: force homepage to funnel landing behavior
    if (shop.shop_type === "funnel" && url.pathname === "/") {
        url.pathname = "/_funnel";
        return NextResponse.rewrite(url, { request: { headers: requestHeaders } });
    }

    return NextResponse.next({ request: { headers: requestHeaders } });
}

export const config = {
    matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
