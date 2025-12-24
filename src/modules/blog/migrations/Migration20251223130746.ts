import { Migration } from "@medusajs/framework/mikro-orm/migrations";

export class Migration20251223130746 extends Migration {

  override async up(): Promise<void> {
    this.addSql(`alter table if exists "post" alter column "sales_channels" type text[] using ("sales_channels"::text[]);`);
    this.addSql(`alter table if exists "post" alter column "sales_channels" drop not null;`);
    this.addSql(`alter table if exists "post" alter column "language_code" type text using ("language_code"::text);`);
    this.addSql(`alter table if exists "post" alter column "language_code" drop not null;`);
  }

  override async down(): Promise<void> {
    this.addSql(`alter table if exists "post" alter column "sales_channels" type text[] using ("sales_channels"::text[]);`);
    this.addSql(`alter table if exists "post" alter column "sales_channels" set not null;`);
    this.addSql(`alter table if exists "post" alter column "language_code" type text using ("language_code"::text);`);
    this.addSql(`alter table if exists "post" alter column "language_code" set not null;`);
  }

}
