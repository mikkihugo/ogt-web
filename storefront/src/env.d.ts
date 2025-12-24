/// <reference path="../.astro/types.d.ts" />

declare namespace App {
    interface Locals {
        salesChannelIds: string[];
        locale: string;
        region: string;
        theme: string;
        currencyCode: string;
    }
}
