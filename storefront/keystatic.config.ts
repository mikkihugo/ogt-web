import { config, fields, collection } from '@keystatic/core';

export default config({
  storage: {
    kind: 'local',
  },
  collections: {
    posts: collection({
      label: 'Blog Posts',
      slugField: 'title',
      path: 'src/content/posts/*',
      format: { contentField: 'content' },
      schema: {
        title: fields.slug({ name: { label: 'Title' } }),
        publishedDate: fields.date({ label: 'Published Date' }),
        excerpt: fields.text({
          label: 'Excerpt',
          multiline: true,
          description: 'A short summary of the post for previews',
        }),
        featuredImage: fields.image({
          label: 'Featured Image',
          directory: 'src/assets/posts',
          publicPath: '../assets/posts/',
        }),
        category: fields.select({
          label: 'Category',
          options: [
            { label: 'Wellness', value: 'wellness' },
            { label: 'Guides', value: 'guides' },
            { label: 'Reviews', value: 'reviews' },
            { label: 'News', value: 'news' },
          ],
          defaultValue: 'wellness',
        }),
        content: fields.markdoc({
          label: 'Content',
          extension: 'md',
        }),
      },
    }),
    pages: collection({
      label: 'Pages',
      slugField: 'title',
      path: 'src/content/pages/*',
      format: { contentField: 'content' },
      schema: {
        title: fields.slug({ name: { label: 'Title' } }),
        description: fields.text({
          label: 'Meta Description',
          multiline: true,
        }),
        content: fields.markdoc({
          label: 'Content',
          extension: 'md',
        }),
      },
    }),
  },
});
