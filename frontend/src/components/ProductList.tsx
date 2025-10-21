import { Product } from '../types/product';
import ProductCard from './ProductCard';
import './ProductList.css';

interface ProductListProps {
  products: Product[];
}

function ProductList({ products }: ProductListProps) {
  if (products.length === 0) {
    return (
      <div className="empty-state">
        <p>No products found.</p>
      </div>
    );
  }

  return (
    <div className="product-list">
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}

export default ProductList;
