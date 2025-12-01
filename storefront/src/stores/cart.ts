import { atom, computed } from 'nanostores';
import { persistentAtom } from '@nanostores/persistent';
import { medusaClient } from '../lib/medusa';
import type { MedusaCart } from '../lib/medusa';

export interface CartItem {
  id: string;
  variantId: string;
  productId: string;
  title: string;
  variantTitle?: string;
  quantity: number;
  price: number;
  image?: string;
}

export interface LocalCart {
  id?: string;
  items: CartItem[];
  regionId?: string;
}

// Persistent local cart storage
export const $localCart = persistentAtom<LocalCart>('cart-storage', {
  items: []
}, {
  encode: JSON.stringify,
  decode: JSON.parse,
});

// Server-side Medusa cart
export const $medusaCart = atom<MedusaCart | null>(null);

// Loading state
export const $cartLoading = atom<boolean>(false);

// Error state
export const $cartError = atom<string | null>(null);

// Computed cart count
export const $cartCount = computed($localCart, (cart) => {
  return cart.items.reduce((sum, item) => sum + item.quantity, 0);
});

// Computed cart total
export const $cartTotal = computed($localCart, (cart) => {
  return cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
});

// Helper to dispatch custom event for cart updates
function dispatchCartUpdate() {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('cart-updated'));
  }
}

// Add item to cart
export async function addToCart(item: Omit<CartItem, 'id'>) {
  const currentCart = $localCart.get();

  // Check if item already exists
  const existingItemIndex = currentCart.items.findIndex(
    (i) => i.variantId === item.variantId
  );

  if (existingItemIndex > -1) {
    // Update quantity
    const updatedItems = [...currentCart.items];
    updatedItems[existingItemIndex].quantity += item.quantity;

    $localCart.set({
      ...currentCart,
      items: updatedItems,
    });
  } else {
    // Add new item
    const newItem: CartItem = {
      ...item,
      id: `item_${Date.now()}_${Math.random().toString(36).substring(7)}`,
    };

    $localCart.set({
      ...currentCart,
      items: [...currentCart.items, newItem],
    });
  }

  dispatchCartUpdate();

  // Sync with Medusa if cart ID exists
  if (currentCart.id) {
    await syncWithMedusa();
  }
}

// Update item quantity
export function updateCartItemQuantity(itemId: string, quantity: number) {
  const currentCart = $localCart.get();

  if (quantity <= 0) {
    removeFromCart(itemId);
    return;
  }

  const updatedItems = currentCart.items.map((item) =>
    item.id === itemId ? { ...item, quantity } : item
  );

  $localCart.set({
    ...currentCart,
    items: updatedItems,
  });

  dispatchCartUpdate();
}

// Remove item from cart
export function removeFromCart(itemId: string) {
  const currentCart = $localCart.get();

  $localCart.set({
    ...currentCart,
    items: currentCart.items.filter((item) => item.id !== itemId),
  });

  dispatchCartUpdate();
}

// Clear cart
export function clearCart() {
  $localCart.set({ items: [] });
  $medusaCart.set(null);
  dispatchCartUpdate();
}

// Sync local cart with Medusa
export async function syncWithMedusa() {
  const localCart = $localCart.get();

  if (localCart.items.length === 0) {
    return;
  }

  $cartLoading.set(true);
  $cartError.set(null);

  try {
    let cartId = localCart.id;

    // Create cart if it doesn't exist
    if (!cartId) {
      const { cart } = await medusaClient.createCart(
        localCart.regionId ? { region_id: localCart.regionId } : undefined
      );
      cartId = cart.id;
      $localCart.set({ ...localCart, id: cartId });
    }

    // Add items to Medusa cart
    for (const item of localCart.items) {
      try {
        await medusaClient.addLineItem(cartId, {
          variant_id: item.variantId,
          quantity: item.quantity,
        });
      } catch (error) {
        console.error('Error adding item to Medusa cart:', error);
      }
    }

    // Fetch updated cart
    const { cart } = await medusaClient.getCart(cartId);
    $medusaCart.set(cart);
  } catch (error) {
    console.error('Error syncing with Medusa:', error);
    $cartError.set(error instanceof Error ? error.message : 'Failed to sync cart');
  } finally {
    $cartLoading.set(false);
  }
}

// Initialize cart from Medusa
export async function initializeCartFromMedusa(cartId: string) {
  $cartLoading.set(true);
  $cartError.set(null);

  try {
    const { cart } = await medusaClient.getCart(cartId);
    $medusaCart.set(cart);

    // Sync with local cart
    const localItems: CartItem[] = cart.items.map((item) => ({
      id: item.id,
      variantId: item.variant.id,
      productId: item.variant.product.id,
      title: item.variant.product.title,
      variantTitle: item.variant.title,
      quantity: item.quantity,
      price: item.unit_price,
      image: item.variant.product.thumbnail,
    }));

    $localCart.set({
      id: cart.id,
      items: localItems,
      regionId: cart.region?.id,
    });

    dispatchCartUpdate();
  } catch (error) {
    console.error('Error initializing cart from Medusa:', error);
    $cartError.set(error instanceof Error ? error.message : 'Failed to load cart');
  } finally {
    $cartLoading.set(false);
  }
}

// Get or create cart ID
export async function getOrCreateCartId(): Promise<string> {
  const localCart = $localCart.get();

  if (localCart.id) {
    return localCart.id;
  }

  try {
    const { cart } = await medusaClient.createCart();
    $localCart.set({ ...localCart, id: cart.id });
    return cart.id;
  } catch (error) {
    console.error('Error creating cart:', error);
    throw error;
  }
}
