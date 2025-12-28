import { Migration } from "@medusajs/framework/mikro-orm/migrations";

export class Migration20251223131143 extends Migration {
  override async up(): Promise<void> {
    this.addSql(
      `alter table if exists "post" rename column "sales_channels" to "channel_config";`,
    );
  }

  override async down(): Promise<void> {
    this.addSql(
      `alter table if exists "post" rename column "channel_config" to "sales_channels";`,
    );
  }
}
