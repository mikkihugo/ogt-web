import { Migration } from "@medusajs/framework/mikro-orm/migrations";

export class Migration20251223130855 extends Migration {

  override async up(): Promise<void> {
    this.addSql(`alter table if exists "post" alter column "sales_channels" drop default;`);
    this.addSql(`alter table if exists "post" alter column "sales_channels" type jsonb using (to_jsonb("sales_channels"));`);
  }

  override async down(): Promise<void> {
    this.addSql(`alter table if exists "post" alter column "sales_channels" type text[] using ("sales_channels"::text[]);`);
  }

}
