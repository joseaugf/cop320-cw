import { Link } from 'react-router-dom';
import './Navigation.css';

function Navigation() {
  return (
    <nav className="navigation">
      <Link to="/" className="nav-link">
        Products
      </Link>
      <Link to="/cart" className="nav-link">
        🛒 Cart
      </Link>
      <Link to="/admin" className="nav-link admin-link">
        ⚙️ Admin
      </Link>
    </nav>
  );
}

export default Navigation;
