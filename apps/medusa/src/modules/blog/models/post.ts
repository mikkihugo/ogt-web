import { model } from "@medusajs/framework/utils";

const Post = model.define("post", {
  id: model.id().primaryKey(),
  title: model.text(),
  slug: model.text().unique(),
  excerpt: model.text().nullable(),
  content: model.text(), // Markdown or rich text
  featured_image: model.text().nullable(),
  category: model.text().nullable(),
  author: model.text().nullable(),
  published_at: model.dateTime().nullable(),
  channel_config: model.json().nullable(),
  language_code: model.text().default("en-US").nullable(),
});

export default Post;
