import { Migration } from "@medusajs/framework/mikro-orm/migrations";

export class Migration20251223125327 extends Migration {
  override async up(): Promise<void> {
    this.addSql(
      `alter table if exists "post" drop constraint if exists "post_slug_unique";`,
    );
    this.addSql(
      `create table if not exists "post" ("id" text not null, "title" text not null, "slug" text not null, "excerpt" text null, "content" text not null, "featured_image" text null, "category" text null, "author" text null, "published_at" timestamptz null, "created_at" timestamptz not null default now(), "updated_at" timestamptz not null default now(), "deleted_at" timestamptz null, constraint "post_pkey" primary key ("id"));`,
    );
    this.addSql(
      `CREATE UNIQUE INDEX IF NOT EXISTS "IDX_post_slug_unique" ON "post" ("slug") WHERE deleted_at IS NULL;`,
    );
    this.addSql(
      `CREATE INDEX IF NOT EXISTS "IDX_post_deleted_at" ON "post" ("deleted_at") WHERE deleted_at IS NULL;`,
    );
  }

  override async down(): Promise<void> {
    this.addSql(`drop table if exists "post" cascade;`);
  }
}
