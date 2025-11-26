// Checkout page functionality with Stripe and Klarna integration

// Initialize Stripe (use your publishable key)
const STRIPE_PUBLISHABLE_KEY = 'pk_test_51234567890'; // Replace with your actual Stripe publishable key
let stripe;
let cardElement;

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  loadCheckoutItems();
  initializePaymentMethods();
  setupPaymentMethodToggle();
  setupCheckoutForm();
});

function loadCheckoutItems() {
  const cart = new ShoppingCart();
  const checkoutItems = document.getElementById('checkout-items');
  const subtotalEl = document.getElementById('summary-subtotal');
  const shippingEl = document.getElementById('summary-shipping');
  const totalEl = document.getElementById('summary-total');
  
  if (cart.items.length === 0) {
    checkoutItems.innerHTML = '<p class="muted">No items in cart</p>';
    return;
  }
  
  // Display cart items
  checkoutItems.innerHTML = cart.items.map(item => `
    <div class="checkout-item">
      <div class="checkout-item-info">
        <div class="checkout-item-name">${item.name}</div>
        <div class="checkout-item-qty">Quantity: ${item.quantity}</div>
      </div>
      <div class="checkout-item-price">$${(item.price * item.quantity).toFixed(2)}</div>
    </div>
  `).join('');
  
  // Calculate totals
  const subtotal = cart.getTotal();
  const shipping = 9.99;
  const total = subtotal + shipping;
  
  subtotalEl.textContent = `$${subtotal.toFixed(2)}`;
  shippingEl.textContent = `$${shipping.toFixed(2)}`;
  totalEl.textContent = `$${total.toFixed(2)}`;
}

function initializePaymentMethods() {
  // Initialize Stripe
  try {
    stripe = Stripe(STRIPE_PUBLISHABLE_KEY);
    const elements = stripe.elements();
    
    cardElement = elements.create('card', {
      style: {
        base: {
          fontSize: '16px',
          color: '#1F2937',
          '::placeholder': {
            color: '#9CA3AF',
          },
        },
      },
    });
    
    cardElement.mount('#stripe-card-element');
    
    cardElement.on('change', function(event) {
      const displayError = document.getElementById('stripe-card-errors');
      if (event.error) {
        displayError.textContent = event.error.message;
      } else {
        displayError.textContent = '';
      }
    });
  } catch (error) {
    console.error('Stripe initialization error:', error);
    document.getElementById('stripe-payment-section').innerHTML = 
      '<p class="payment-errors">⚠️ Demo mode: Using test Stripe key. Replace with your actual publishable key in checkout.js</p>';
  }
  
  // Initialize Klarna (placeholder - requires backend setup)
  initializeKlarna();
}

function initializeKlarna() {
  const klarnaContainer = document.getElementById('klarna-payments-container');
  if (klarnaContainer) {
    klarnaContainer.innerHTML = `
      <div style="padding: 20px; background: #FFE5EC; border-radius: 8px; text-align: center;">
        <p style="margin: 0; color: #6B7280;">
          💳 Klarna integration requires backend setup.<br>
          <small>See README for Klarna API integration steps.</small>
        </p>
      </div>
    `;
  }
}

function setupPaymentMethodToggle() {
  const paymentRadios = document.querySelectorAll('input[name="payment-method"]');
  const stripeSection = document.getElementById('stripe-payment-section');
  const klarnaSection = document.getElementById('klarna-payment-section');
  
  paymentRadios.forEach(radio => {
    radio.addEventListener('change', function() {
      if (this.value === 'stripe') {
        stripeSection.style.display = 'block';
        klarnaSection.style.display = 'none';
      } else if (this.value === 'klarna') {
        stripeSection.style.display = 'none';
        klarnaSection.style.display = 'block';
      }
    });
  });
}

function setupCheckoutForm() {
  const submitButton = document.getElementById('submit-payment');
  const shippingForm = document.getElementById('shipping-form');
  
  if (submitButton) {
    submitButton.addEventListener('click', function(e) {
      e.preventDefault();
      
      // Validate shipping form
      if (!shippingForm.checkValidity()) {
        shippingForm.reportValidity();
        return;
      }
      
      // Get selected payment method
      const paymentMethod = document.querySelector('input[name="payment-method"]:checked').value;
      
      if (paymentMethod === 'stripe') {
        processStripePayment();
      } else if (paymentMethod === 'klarna') {
        processKlarnaPayment();
      }
    });
  }
}

async function processStripePayment() {
  const submitButton = document.getElementById('submit-payment');
  const processingDiv = document.getElementById('payment-processing');
  const errorDiv = document.getElementById('payment-error');
  const successDiv = document.getElementById('payment-success');
  
  // Show processing state
  submitButton.disabled = true;
  processingDiv.style.display = 'block';
  errorDiv.style.display = 'none';
  successDiv.style.display = 'none';
  
  try {
    // In a real implementation, you would:
    // 1. Send order details to your backend
    // 2. Backend creates a PaymentIntent with Stripe
    // 3. Backend returns client_secret
    // 4. Use client_secret to confirm payment
    
    // Demo: Simulate payment processing
    await simulatePayment();
    
    // For demo purposes, we'll show success
    // In production, use: const {error} = await stripe.confirmCardPayment(clientSecret, {...})
    
    processingDiv.style.display = 'none';
    successDiv.style.display = 'block';
    
    // Clear cart after successful payment
    const cart = new ShoppingCart();
    cart.clearCart();
    
  } catch (error) {
    processingDiv.style.display = 'none';
    errorDiv.style.display = 'block';
    document.getElementById('payment-error-message').textContent = 
      'Demo mode: ' + (error.message || 'Payment processing failed');
    submitButton.disabled = false;
  }
}

async function processKlarnaPayment() {
  const submitButton = document.getElementById('submit-payment');
  const processingDiv = document.getElementById('payment-processing');
  const errorDiv = document.getElementById('payment-error');
  const successDiv = document.getElementById('payment-success');
  
  submitButton.disabled = true;
  processingDiv.style.display = 'block';
  errorDiv.style.display = 'none';
  successDiv.style.display = 'none';
  
  try {
    // In a real implementation:
    // 1. Call your backend to create Klarna session
    // 2. Get authorization token from Klarna
    // 3. Process the payment
    
    // Demo simulation
    await simulatePayment();
    
    processingDiv.style.display = 'none';
    successDiv.style.display = 'block';
    
    const cart = new ShoppingCart();
    cart.clearCart();
    
  } catch (error) {
    processingDiv.style.display = 'none';
    errorDiv.style.display = 'block';
    document.getElementById('payment-error-message').textContent = 
      'Demo mode: ' + (error.message || 'Klarna payment failed');
    submitButton.disabled = false;
  }
}

function simulatePayment() {
  return new Promise((resolve) => {
    setTimeout(resolve, 2000);
  });
}

function resetPayment() {
  document.getElementById('payment-error').style.display = 'none';
  document.getElementById('submit-payment').disabled = false;
}

// Get shipping form data
function getShippingData() {
  const form = document.getElementById('shipping-form');
  return {
    firstName: form.firstName.value,
    lastName: form.lastName.value,
    email: form.email.value,
    address: form.address.value,
    city: form.city.value,
    zipCode: form.zipCode.value,
    country: form.country.value
  };
}
