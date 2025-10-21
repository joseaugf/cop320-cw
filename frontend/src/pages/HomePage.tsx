import { useState, useEffect } from 'react';
import { getProducts } from '../api/products';
import { Product } from '../types/product';
import ProductList from '../components/ProductList';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import './HomePage.css';

function HomePage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await getProducts();
      setProducts(data);
    } catch (err: any) {
      setError(err.response?.data?.error?.message || 'Failed to load products. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProducts();
  }, []);

  return (
    <div className="home-page">
      <div className="page-header">
        <h1>Our Products</h1>
        <p className="page-subtitle">Everything your pet needs</p>
      </div>

      {loading && <LoadingSpinner />}
      {error && <ErrorMessage message={error} onRetry={fetchProducts} />}
      {!loading && !error && <ProductList products={products} />}
    </div>
  );
}

export default HomePage;
