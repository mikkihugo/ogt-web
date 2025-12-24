import { Migration } from "@medusajs/framework/mikro-orm/migrations";

export class Migration20251223130557 extends Migration {

  override async up(): Promise<void> {
    this.addSql(`alter table if exists "post" add column if not exists "sales_channels" text[] not null default '{}', add column if not exists "language_code" text not null default 'en-US';`);
  }

  override async down(): Promise<void> {
    this.addSql(`alter table if exists "post" drop column if exists "sales_channels", drop column if exists "language_code";`);
  }

}
