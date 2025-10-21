import { Link } from 'react-router-dom';
import { Product } from '../types/product';
import './ProductCard.css';

interface ProductCardProps {
  product: Product;
}

function ProductCard({ product }: ProductCardProps) {
  return (
    <Link to={`/product/${product.id}`} className="product-card">
      <div className="product-image">
        <img src={product.image_url} alt={product.name} />
      </div>
      <div className="product-info">
        <h3 className="product-name">{product.name}</h3>
        <p className="product-category">{product.category}</p>
        <p className="product-price">${product.price.toFixed(2)}</p>
        {product.stock === 0 && (
          <span className="out-of-stock">Out of Stock</span>
        )}
      </div>
    </Link>
  );
}

export default ProductCard;
