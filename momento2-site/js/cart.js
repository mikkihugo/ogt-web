// Shopping Cart Management
class ShoppingCart {
  constructor() {
    this.items = this.loadCart();
    this.updateCartUI();
  }

  loadCart() {
    const saved = localStorage.getItem('momento2_cart');
    return saved ? JSON.parse(saved) : [];
  }

  saveCart() {
    localStorage.setItem('momento2_cart', JSON.stringify(this.items));
  }

  addItem(id, name, price, quantity = 1) {
    const existing = this.items.find(item => item.id === id);
    
    if (existing) {
      existing.quantity += quantity;
    } else {
      this.items.push({ id, name, price, quantity });
    }
    
    this.saveCart();
    this.updateCartUI();
    this.showNotification(`${name} added to cart`);
  }

  removeItem(id) {
    this.items = this.items.filter(item => item.id !== id);
    this.saveCart();
    this.updateCartUI();
  }

  updateQuantity(id, quantity) {
    const item = this.items.find(item => item.id === id);
    if (item) {
      item.quantity = Math.max(1, quantity);
      this.saveCart();
      this.updateCartUI();
    }
  }

  getTotal() {
    return this.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  }

  getItemCount() {
    return this.items.reduce((sum, item) => sum + item.quantity, 0);
  }

  updateCartUI() {
    // Update cart badge
    const badge = document.getElementById('cart-count');
    if (badge) {
      const count = this.getItemCount();
      badge.textContent = count;
      badge.style.display = count > 0 ? 'block' : 'none';
    }

    // Update cart sidebar
    const cartItems = document.getElementById('cart-items');
    const cartTotal = document.getElementById('cart-total');
    
    if (cartItems) {
      if (this.items.length === 0) {
        cartItems.innerHTML = '<p class="muted">Your cart is empty</p>';
      } else {
        // Build cart items safely without innerHTML injection
        cartItems.innerHTML = '';
        this.items.forEach(item => {
          const cartItem = document.createElement('div');
          cartItem.className = 'cart-item';
          
          const itemImage = document.createElement('div');
          itemImage.className = 'cart-item-image';
          itemImage.style.backgroundImage = `url('https://via.placeholder.com/80x80?text=${encodeURIComponent(item.name)}')`;
          
          const itemDetails = document.createElement('div');
          itemDetails.className = 'cart-item-details';
          
          const itemName = document.createElement('div');
          itemName.className = 'cart-item-name';
          itemName.textContent = item.name;
          
          const itemPrice = document.createElement('div');
          itemPrice.className = 'cart-item-price';
          itemPrice.textContent = '$' + parseFloat(item.price).toFixed(2);
          
          const itemQuantity = document.createElement('div');
          itemQuantity.className = 'cart-item-quantity';
          
          const minusBtn = document.createElement('button');
          minusBtn.className = 'qty-btn';
          minusBtn.textContent = '-';
          minusBtn.onclick = () => this.updateQuantity(item.id, item.quantity - 1);
          
          const qtySpan = document.createElement('span');
          qtySpan.textContent = item.quantity;
          
          const plusBtn = document.createElement('button');
          plusBtn.className = 'qty-btn';
          plusBtn.textContent = '+';
          plusBtn.onclick = () => this.updateQuantity(item.id, item.quantity + 1);
          
          itemQuantity.appendChild(minusBtn);
          itemQuantity.appendChild(qtySpan);
          itemQuantity.appendChild(plusBtn);
          
          itemDetails.appendChild(itemName);
          itemDetails.appendChild(itemPrice);
          itemDetails.appendChild(itemQuantity);
          
          const removeBtn = document.createElement('button');
          removeBtn.className = 'cart-item-remove';
          removeBtn.textContent = '×';
          removeBtn.onclick = () => this.removeItem(item.id);
          
          cartItem.appendChild(itemImage);
          cartItem.appendChild(itemDetails);
          cartItem.appendChild(removeBtn);
          
          cartItems.appendChild(cartItem);
        });
      }
    }
    
    if (cartTotal) {
      cartTotal.textContent = `$${this.getTotal().toFixed(2)}`;
    }
  }

  showNotification(message) {
    // Simple notification - could be enhanced with a better UI
    const notification = document.createElement('div');
    notification.style.cssText = `
      position: fixed;
      top: 100px;
      right: 20px;
      background: #10B981;
      color: white;
      padding: 16px 24px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 10000;
      animation: slideIn 0.3s ease-out;
    `;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease-out';
      setTimeout(() => notification.remove(), 300);
    }, 2000);
  }

  clearCart() {
    this.items = [];
    this.saveCart();
    this.updateCartUI();
  }
}

// Initialize cart
const cart = new ShoppingCart();

// Cart toggle function
function toggleCart() {
  const sidebar = document.getElementById('cart-sidebar');
  if (sidebar) {
    sidebar.classList.toggle('open');
  }
}

// Add to cart function
function addToCart(id, name, price) {
  cart.addItem(id, name, price);
}

// Add CSS animation for notifications
if (!document.getElementById('cart-animations')) {
  const style = document.createElement('style');
  style.id = 'cart-animations';
  style.textContent = `
    @keyframes slideIn {
      from {
        transform: translateX(400px);
        opacity: 0;
      }
      to {
        transform: translateX(0);
        opacity: 1;
      }
    }
    @keyframes slideOut {
      from {
        transform: translateX(0);
        opacity: 1;
      }
      to {
        transform: translateX(400px);
        opacity: 0;
      }
    }
  `;
  document.head.appendChild(style);
}
