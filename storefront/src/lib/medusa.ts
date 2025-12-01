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
  }): Promise<{ products: MedusaProduct[]; count: number; limit: number; offset: number }> {
    const searchParams = new URLSearchParams();
    if (params?.limit) searchParams.set('limit', params.limit.toString());
    if (params?.offset) searchParams.set('offset', params.offset.toString());
    if (params?.category_id) searchParams.set('category_id[]', params.category_id);
    if (params?.collection_id) searchParams.set('collection_id[]', params.collection_id);
    if (params?.q) searchParams.set('q', params.q);

    const query = searchParams.toString();
    return this.fetch(`/store/products${query ? `?${query}` : ''}`);
  }

  async getProduct(id: string): Promise<{ product: MedusaProduct }> {
    return this.fetch(`/store/products/${id}`);
  }

  async getProductByHandle(handle: string): Promise<MedusaProduct | null> {
    try {
      const { products } = await this.getProducts({ limit: 1 });
      // Filter by handle on client side since Medusa API doesn't support handle filtering directly
      const response = await this.fetch<{ products: MedusaProduct[] }>(`/store/products?handle=${handle}`);
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
  const price = variant?.prices?.[0];
  if (!price) return 'Price unavailable';
  return formatPrice(price.amount, price.currency_code);
}

export function getProductImage(product: MedusaProduct): string {
  return product.thumbnail || product.images?.[0]?.url || '/placeholder-product.jpg';
}
