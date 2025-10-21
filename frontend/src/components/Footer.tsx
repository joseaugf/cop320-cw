import './Footer.css';

function Footer() {
  return (
    <footer className="footer">
      <div className="footer-container">
        <p>© 2025 Petshop - Observability Demo</p>
        <p className="footer-note">
          Built with OpenTelemetry & AWS CloudWatch
        </p>
      </div>
    </footer>
  );
}

export default Footer;
