import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getProductById } from '../api/products';
import { addToCart } from '../api/cart';
import { Product } from '../types/product';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import './ProductDetailPage.css';

function ProductDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [addSuccess, setAddSuccess] = useState(false);

  const fetchProduct = async () => {
    if (!id) return;
    
    try {
      setLoading(true);
      setError(null);
      const data = await getProductById(id);
      setProduct(data);
    } catch (err: any) {
      setError(err.response?.data?.error?.message || 'Failed to load product. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddToCart = async () => {
    if (!product) return;

    try {
      setAdding(true);
      await addToCart(product.id, product.name, product.price, 1);
      setAddSuccess(true);
      setTimeout(() => setAddSuccess(false), 3000);
    } catch (err: any) {
      alert(err.response?.data?.error?.message || 'Failed to add to cart. Please try again.');
    } finally {
      setAdding(false);
    }
  };

  useEffect(() => {
    fetchProduct();
  }, [id]);

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} onRetry={fetchProduct} />;
  if (!product) return <ErrorMessage message="Product not found" />;

  return (
    <div className="product-detail-page">
      <div className="product-detail">
        <div className="product-detail-image">
          <img src={product.image_url} alt={product.name} />
        </div>
        <div className="product-detail-info">
          <span className="product-detail-category">{product.category}</span>
          <h1 className="product-detail-name">{product.name}</h1>
          <p className="product-detail-price">${product.price.toFixed(2)}</p>
          <p className="product-detail-description">{product.description}</p>
          <p className="product-detail-stock">
            Stock:{' '}
            {product.stock > 0 ? (
              <span className="stock-available">{product.stock} available</span>
            ) : (
              <span className="stock-unavailable">Out of stock</span>
            )}
          </p>
          
          {addSuccess && (
            <div className="success-message">✓ Added to cart!</div>
          )}

          <div className="product-actions">
            <Link to="/" className="back-button">
              ← Back to Products
            </Link>
            <button
              className="add-to-cart-button"
              onClick={handleAddToCart}
              disabled={product.stock === 0 || adding}
            >
              {adding ? 'Adding...' : 'Add to Cart'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default ProductDetailPage;
