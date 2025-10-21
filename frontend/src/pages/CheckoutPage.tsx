import { useState, FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { processCheckout, Order } from '../api/checkout';
import LoadingSpinner from '../components/LoadingSpinner';
import './CheckoutPage.css';

interface FormErrors {
  email?: string;
  address?: string;
}

function CheckoutPage() {
  const [email, setEmail] = useState('');
  const [address, setAddress] = useState('');
  const [errors, setErrors] = useState<FormErrors>({});
  const [submitting, setSubmitting] = useState(false);
  const [order, setOrder] = useState<Order | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const validateForm = (): boolean => {
    const newErrors: FormErrors = {};

    // Email validation
    if (!email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    // Address validation
    if (!address.trim()) {
      newErrors.address = 'Shipping address is required';
    } else if (address.trim().length < 10) {
      newErrors.address = 'Please enter a complete shipping address';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;

    try {
      setSubmitting(true);
      setSubmitError(null);
      
      // Get cart items from localStorage
      const cartData = localStorage.getItem('cart');
      const cart = cartData ? JSON.parse(cartData) : { items: [] };
      
      const orderData = await processCheckout({
        customerEmail: email,
        shippingAddress: address,
        items: cart.items,
      });
      setOrder(orderData);
      // Clear cart from localStorage on successful checkout
      localStorage.removeItem('cart');
    } catch (err: any) {
      const errorMessage = err.response?.data?.error?.message || 
        'Failed to process checkout. Please try again.';
      setSubmitError(errorMessage);
    } finally {
      setSubmitting(false);
    }
  };

  if (submitting) {
    return <LoadingSpinner />;
  }

  if (order) {
    return (
      <div className="checkout-page">
        <div className="order-confirmation">
          <div className="success-icon">✓</div>
          <h2>Order Confirmed!</h2>
          <p className="order-id">
            Order ID:
            <br />
            <span className="order-id-value">{order.id}</span>
          </p>
          <p className="order-total">Total: ${order.total.toFixed(2)}</p>
          <p className="confirmation-message">
            Thank you for your order! A confirmation email has been sent to{' '}
            <strong>{order.customerEmail}</strong>.
            <br />
            Your order will be shipped to the provided address.
          </p>
          <Link to="/" className="home-button">
            Continue Shopping
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="checkout-page">
      <div className="page-header">
        <h1>Checkout</h1>
      </div>

      <form className="checkout-form" onSubmit={handleSubmit}>
        {submitError && (
          <div className="form-error" style={{ marginBottom: '1rem', padding: '1rem', backgroundColor: '#ffe0e0', borderRadius: '4px' }}>
            {submitError}
          </div>
        )}

        <div className="form-group">
          <label htmlFor="email" className="form-label">
            Email Address *
          </label>
          <input
            type="email"
            id="email"
            className="form-input"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="your.email@example.com"
          />
          {errors.email && <p className="form-error">{errors.email}</p>}
        </div>

        <div className="form-group">
          <label htmlFor="address" className="form-label">
            Shipping Address *
          </label>
          <textarea
            id="address"
            className="form-textarea"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            placeholder="Enter your complete shipping address including street, city, state, and zip code"
          />
          {errors.address && <p className="form-error">{errors.address}</p>}
        </div>

        <div className="form-actions">
          <Link to="/cart" className="cancel-button">
            Back to Cart
          </Link>
          <button type="submit" className="submit-button" disabled={submitting}>
            {submitting ? 'Processing...' : 'Place Order'}
          </button>
        </div>
      </form>
    </div>
  );
}

export default CheckoutPage;
