import { Link } from 'react-router-dom';
import Navigation from './Navigation';
import './Header.css';

function Header() {
  return (
    <header className="header">
      <div className="header-container">
        <Link to="/" className="logo">
          <span className="logo-icon">🐾</span>
          <span className="logo-text">Petshop</span>
        </Link>
        <Navigation />
      </div>
    </header>
  );
}

export default Header;
