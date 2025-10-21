import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { getCart, updateCartItem, removeCartItem, clearCart, Cart } from '../api/cart';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import './CartPage.css';

function CartPage() {
  const navigate = useNavigate();
  const [cart, setCart] = useState<Cart | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updating, setUpdating] = useState<string | null>(null);

  const fetchCart = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await getCart();
      setCart(data);
    } catch (err: any) {
      setError(err.response?.data?.error?.message || 'Failed to load cart. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateQuantity = async (productId: string, quantity: number) => {
    if (quantity < 1) return;

    try {
      setUpdating(productId);
      const updatedCart = await updateCartItem(productId, quantity);
      setCart(updatedCart);
    } catch (err: any) {
      alert(err.response?.data?.error?.message || 'Failed to update quantity. Please try again.');
    } finally {
      setUpdating(null);
    }
  };

  const handleRemoveItem = async (productId: string) => {
    try {
      setUpdating(productId);
      const updatedCart = await removeCartItem(productId);
      setCart(updatedCart);
    } catch (err: any) {
      alert(err.response?.data?.error?.message || 'Failed to remove item. Please try again.');
    } finally {
      setUpdating(null);
    }
  };

  const handleClearCart = async () => {
    if (!window.confirm('Are you sure you want to clear your cart?')) return;

    try {
      setLoading(true);
      await clearCart();
      setCart({ sessionId: cart?.sessionId || '', items: [], total: 0 });
    } catch (err: any) {
      alert(err.response?.data?.error?.message || 'Failed to clear cart. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleCheckout = () => {
    navigate('/checkout');
  };

  useEffect(() => {
    fetchCart();
  }, []);

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} onRetry={fetchCart} />;

  const isEmpty = !cart || cart.items.length === 0;

  return (
    <div className="cart-page">
      <div className="page-header">
        <h1>Shopping Cart</h1>
      </div>

      {isEmpty ? (
        <div className="empty-cart">
          <div className="empty-cart-icon">🛒</div>
          <h2>Your cart is empty</h2>
          <p>Add some products to get started!</p>
          <Link to="/" className="continue-shopping-button">
            Browse Products
          </Link>
        </div>
      ) : (
        <>
          <div className="cart-items">
            {cart.items.map((item) => (
              <div key={item.productId} className="cart-item">
                <div className="cart-item-info">
                  <h3 className="cart-item-name">{item.name}</h3>
                  <p className="cart-item-price">${item.price.toFixed(2)} each</p>
                </div>
                <div className="cart-item-controls">
                  <div className="quantity-controls">
                    <button
                      className="quantity-button"
                      onClick={() => handleUpdateQuantity(item.productId, item.quantity - 1)}
                      disabled={updating === item.productId || item.quantity <= 1}
                    >
                      -
                    </button>
                    <span className="quantity-display">{item.quantity}</span>
                    <button
                      className="quantity-button"
                      onClick={() => handleUpdateQuantity(item.productId, item.quantity + 1)}
                      disabled={updating === item.productId}
                    >
                      +
                    </button>
                  </div>
                  <p className="cart-item-subtotal">
                    ${(item.price * item.quantity).toFixed(2)}
                  </p>
                  <button
                    className="remove-button"
                    onClick={() => handleRemoveItem(item.productId)}
                    disabled={updating === item.productId}
                  >
                    Remove
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="cart-summary">
            <div className="cart-total">
              <span className="total-label">Total:</span>
              <span className="total-amount">${cart.total.toFixed(2)}</span>
            </div>
            <div className="cart-actions">
              <button className="clear-cart-button" onClick={handleClearCart}>
                Clear Cart
              </button>
              <button className="checkout-button" onClick={handleCheckout}>
                Proceed to Checkout
              </button>
            </div>
            <Link to="/" className="continue-shopping-link">
              ← Continue Shopping
            </Link>
          </div>
        </>
      )}
    </div>
  );
}

export default CartPage;
