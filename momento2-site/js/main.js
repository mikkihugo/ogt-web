// Main JavaScript for Momento2 site

// Product Modal Functions
function openProduct(event, productId) {
  event.preventDefault();
  
  const products = {
    1: { name: 'Elegance Vibe', price: 129.00, description: 'Premium silicone with whisper-quiet motor. Features 10 vibration patterns and fully waterproof design. USB rechargeable with up to 2 hours of use per charge.' },
    2: { name: 'Silk Wand', price: 89.00, description: 'Compact and ergonomic design perfect for travel. Soft-touch silicone exterior with powerful yet quiet motor. 5 speed settings.' },
    3: { name: 'Serene Oil', price: 29.00, description: 'Natural, fragrance-free massage oil formulated for sensitive skin. Made with organic ingredients. Non-staining and easy to clean.' },
    4: { name: 'Luxe Collection', price: 199.00, description: 'Complete wellness kit including premium device, luxury oil, silk storage pouch, and USB charger. Everything you need for a complete experience.' },
    5: { name: 'Velvet Touch', price: 149.00, description: 'Rechargeable premium device with 12 intensity settings. Made from body-safe silicone. Includes travel case and USB charging cable.' },
    6: { name: 'Bliss Serum', price: 39.00, description: 'Organic arousal gel with natural warming effect. Water-based formula safe for sensitive skin. Made with botanical extracts.' }
  };
  
  const product = products[productId];
  if (product) {
    const modal = document.getElementById('product-modal');
    const title = document.getElementById('modal-title');
    
    title.textContent = product.name;
    
    // Update modal content with product details (sanitize text)
    const modalPanel = modal.querySelector('.modal-panel');
    const mutedP = modalPanel.querySelector('.muted');
    
    // Create elements safely without innerHTML
    const priceEl = document.createElement('p');
    priceEl.style.cssText = 'text-align: left; margin-top: 16px;';
    
    const priceStrong = document.createElement('strong');
    priceStrong.textContent = 'Price: $' + parseFloat(product.price).toFixed(2);
    
    const desc = document.createTextNode(product.description);
    
    priceEl.appendChild(priceStrong);
    priceEl.appendChild(document.createElement('br'));
    priceEl.appendChild(document.createElement('br'));
    priceEl.appendChild(desc);
    
    mutedP.innerHTML = '';
    mutedP.appendChild(priceEl);
    
    // Update modal actions to include add to cart
    const modalActions = modalPanel.querySelector('.modal-actions');
    const nameEl = document.createElement('div');
    nameEl.textContent = product.name;
    modalActions.innerHTML = `
      <button class="btn btn-primary" data-product-id="${parseInt(productId)}" data-product-name="${nameEl.textContent}" data-product-price="${parseFloat(product.price)}">Add to Cart</button>
      <button class="btn outline" onclick="closeModal()">Close</button>
    `;
    
    // Add event listener for add to cart button
    modalActions.querySelector('[data-product-id]').addEventListener('click', function() {
      addToCart(
        parseInt(this.dataset.productId),
        this.dataset.productName,
        parseFloat(this.dataset.productPrice)
      );
      closeModal();
    });
    
    modal.setAttribute('aria-hidden', 'false');
    document.body.classList.add('no-scroll');
  }
}

function closeModal() {
  const modal = document.getElementById('product-modal');
  modal.setAttribute('aria-hidden', 'true');
  document.body.classList.remove('no-scroll');
}

// Close modal on background click
document.addEventListener('DOMContentLoaded', function() {
  const modal = document.getElementById('product-modal');
  if (modal) {
    modal.addEventListener('click', function(e) {
      if (e.target === modal) {
        closeModal();
      }
    });
  }
  
  // Close cart on outside click
  document.addEventListener('click', function(e) {
    const cartSidebar = document.getElementById('cart-sidebar');
    const cartIcon = document.querySelector('.cart-icon');
    
    if (cartSidebar && cartSidebar.classList.contains('open')) {
      if (!cartSidebar.contains(e.target) && !cartIcon.contains(e.target)) {
        cartSidebar.classList.remove('open');
      }
    }
  });
  
  // Smooth scrolling for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const href = this.getAttribute('href');
      if (href !== '#' && href.length > 1) {
        const target = document.querySelector(href);
        if (target) {
          e.preventDefault();
          target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          });
        }
      }
    });
  });
});

// Escape key to close modal and cart
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    closeModal();
    const cartSidebar = document.getElementById('cart-sidebar');
    if (cartSidebar && cartSidebar.classList.contains('open')) {
      cartSidebar.classList.remove('open');
    }
  }
});
