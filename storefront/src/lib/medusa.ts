// Medusa v2 API Client
const MEDUSA_BACKEND_URL = import.meta.env.PUBLIC_MEDUSA_BACKEND_URL || 'https://api.orgasmtoy.com';
const PUBLISHABLE_API_KEY = import.meta.env.PUBLIC_MEDUSA_PUBLISHABLE_KEY || '';

export interface MedusaProduct {
  id: string;
  title: string;
  handle: string;
  description?: string;
  thumbnail?: string;
  images?: Array<{ url: string; id: string }>;
  variants?: Array<{
    id: string;
    title: string;
    prices?: Array<{
      amount: number;
      currency_code: string;
    }>;
    inventory_quantity?: number;
    options?: Array<{
      value: string;
      option: { title: string };
    }>;
  }>;
  options?: Array<{
    id: string;
    title: string;
    values: Array<{ id: string; value: string }>;
  }>;
  categories?: Array<{
    id: string;
    name: string;
    handle: string;
  }>;
  collection?: {
    id: string;
    title: string;
    handle: string;
  };
  tags?: Array<{
    id: string;
    value: string;
  }>;
}

export interface MedusaCart {
  id: string;
  email?: string;
  items: Array<{
    id: string;
    title: string;
    quantity: number;
    variant: {
      id: string;
      title: string;
      product: {
        id: string;
        title: string;
        thumbnail?: string;
      };
    };
    unit_price: number;
    total: number;
  }>;
  subtotal: number;
  total: number;
  shipping_total?: number;
  tax_total?: number;
  region?: {
    id: string;
    name: string;
    currency_code: string;
  };
}

export interface MedusaRegion {
  id: string;
  name: string;
  currency_code: string;
  countries: Array<{
    id: string;
    name: string;
    iso_2: string;
  }>;
}

export interface MedusaPost {
  id: string;
  title: string;
  slug: string;
  excerpt: string;
  content: string;
  featured_image?: string;
  category: string;
  published_at: string;
}

class MedusaClient {
  private baseURL: string;
  private publishableKey: string;

  constructor(baseURL: string, publishableKey: string) {
    this.baseURL = baseURL;
    this.publishableKey = publishableKey;
  }

  private async fetch<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const headers = new Headers(options.headers);

    if (this.publishableKey) {
      headers.set('x-publishable-api-key', this.publishableKey);
    }
    headers.set('Content-Type', 'application/json');

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Medusa API error: ${response.status} - ${error}`);
    }

    return response.json();
  }

  // Products
  async getProducts(params?: {
    limit?: number;
    offset?: number;
    category_id?: string;
    collection_id?: string;
    q?: string;
    region_id?: string;
    currency_code?: string;
    sales_channel_id?: string;
  }, customHeaders?: HeadersInit): Promise<{ products: MedusaProduct[]; count: number; limit: number; offset: number }> {
    const searchParams = new URLSearchParams();
    if (params?.limit) searchParams.set('limit', params.limit.toString());
    if (params?.offset) searchParams.set('offset', params.offset.toString());
    if (params?.category_id) searchParams.set('category_id[]', params.category_id);
    if (params?.collection_id) searchParams.set('collection_id[]', params.collection_id);
    if (params?.q) searchParams.set('q', params.q);
    if (params?.region_id) searchParams.set('region_id', params.region_id);
    if (params?.currency_code) searchParams.set('currency_code', params.currency_code);
    if (params?.sales_channel_id) searchParams.set('sales_channel_id[]', params.sales_channel_id);

    // Ensure prices are included in the response
    searchParams.set('fields', '*variants.prices');

    const query = searchParams.toString();
    return this.fetch(`/store/products${query ? `?${query}` : ''}`, { headers: customHeaders });
  }

  async getProduct(id: string): Promise<{ product: MedusaProduct }> {
    return this.fetch(`/store/products/${id}?fields=*variants.prices`);
  }

  async getProductByHandle(handle: string): Promise<MedusaProduct | null> {
    try {
      const response = await this.fetch<{ products: MedusaProduct[] }>(`/store/products?handle=${handle}&fields=*variants.prices`);
      return response.products[0] || null;
    } catch (error) {
      console.error('Error fetching product by handle:', error);
      return null;
    }
  }

  // Carts
  async createCart(data?: { region_id?: string }): Promise<{ cart: MedusaCart }> {
    return this.fetch('/store/carts', {
      method: 'POST',
      body: JSON.stringify(data || {}),
    });
  }

  async getCart(cartId: string): Promise<{ cart: MedusaCart }> {
    return this.fetch(`/store/carts/${cartId}`);
  }

  async addLineItem(
    cartId: string,
    data: { variant_id: string; quantity: number }
  ): Promise<{ cart: MedusaCart }> {
    return this.fetch(`/store/carts/${cartId}/line-items`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updateLineItem(
    cartId: string,
    lineItemId: string,
    data: { quantity: number }
  ): Promise<{ cart: MedusaCart }> {
    return this.fetch(`/store/carts/${cartId}/line-items/${lineItemId}`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async removeLineItem(cartId: string, lineItemId: string): Promise<{ cart: MedusaCart }> {
    return this.fetch(`/store/carts/${cartId}/line-items/${lineItemId}`, {
      method: 'DELETE',
    });
  }

  async updateCart(
    cartId: string,
    data: { email?: string; shipping_address?: any; billing_address?: any }
  ): Promise<{ cart: MedusaCart }> {
    return this.fetch(`/store/carts/${cartId}`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async completeCart(cartId: string): Promise<{ type: string; data: any }> {
    return this.fetch(`/store/carts/${cartId}/complete`, {
      method: 'POST',
    });
  }

  // Regions
  async getRegions(): Promise<{ regions: MedusaRegion[] }> {
    return this.fetch('/store/regions');
  }

  async getRegion(regionId: string): Promise<{ region: MedusaRegion }> {
    return this.fetch(`/store/regions/${regionId}`);
  }

  // Blog
  async getPosts(params?: {
    limit?: number;
    offset?: number;
    sales_channel_id?: string;
  }): Promise<{ posts: MedusaPost[]; count: number }> {
    const searchParams = new URLSearchParams();
    if (params?.limit) searchParams.set('limit', params.limit.toString());
    if (params?.offset) searchParams.set('offset', params.offset.toString());

    const headers: HeadersInit = {};
    if (params?.sales_channel_id) {
      // @ts-ignore
      headers['x-sales-channel-id'] = params.sales_channel_id;
    }

    const query = searchParams.toString();
    return this.fetch(`/store/blog${query ? `?${query}` : ''}`, { headers });
  }

  async getPostBySlug(slug: string, options?: { sales_channel_id?: string }): Promise<MedusaPost | null> {
    const { posts } = await this.getPosts({
      limit: 1,
      sales_channel_id: options?.sales_channel_id
    });
    // Filter client-side if API doesn't support slug filtering directly, 
    // BUT usually the list endpoint might support q or filters. 
    // In our case, we haven't implemented slug filtering in the backend route explicitly yet, 
    // but the service `listPosts` DOES support it if passed in filters.
    // However, our backend route `src/api/store/blog/route.ts` currently DOES NOT map query params to service filters except logic we added.
    // Wait, let's double check backend route.

    // Actually, looking at `src/api/store/blog/route.ts` again, 
    // we only explicitly handled `x-sales-channel-id`.
    // The `blogModuleService.listPosts()` call in the route was:
    // `const posts = await blogModuleService.listPosts()` (fetching ALL).
    // And then we filtered in memory.

    // So `getPosts` returns ALL posts filtered by channel.
    // We can find the slug match here in the client for now.

    return posts.find(p => p.slug === slug) || null;
  }
}

export const medusaClient = new MedusaClient(MEDUSA_BACKEND_URL, PUBLISHABLE_API_KEY);

// Utility functions
export function formatPrice(amount: number, currencyCode: string = 'usd'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currencyCode.toUpperCase(),
  }).format(amount / 100);
}

export function getProductPrice(product: MedusaProduct): string {
  const variant = product.variants?.[0];
  if (!variant || !variant.prices || variant.prices.length === 0) {
    return 'Price unavailable';
  }

  // Prefer USD if available
  const price = variant.prices.find(p => p.currency_code === 'usd') || variant.prices[0];
  return formatPrice(price.amount, price.currency_code);
}

export function getProductImage(product: MedusaProduct): string {
  return product.thumbnail || product.images?.[0]?.url || '/placeholder-product.jpg';
}
