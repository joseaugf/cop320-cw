import { Component, ReactNode } from 'react';
import { trace } from '@opentelemetry/api';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: any) {
    // Log error to OpenTelemetry
    const tracer = trace.getTracer('petshop-frontend');
    const span = tracer.startSpan('error.boundary');
    
    span.recordException(error);
    span.setAttributes({
      'error.type': 'react.error.boundary',
      'error.message': error.message,
      'error.stack': error.stack || '',
      'component.stack': errorInfo.componentStack || '',
    });
    
    span.end();

    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100vh',
          padding: '2rem',
          textAlign: 'center',
        }}>
          <h1 style={{ fontSize: '3rem', marginBottom: '1rem' }}>⚠️</h1>
          <h2 style={{ marginBottom: '1rem' }}>Something went wrong</h2>
          <p style={{ color: '#666', marginBottom: '2rem' }}>
            We're sorry for the inconvenience. Please try refreshing the page.
          </p>
          <button
            onClick={() => window.location.reload()}
            style={{
              backgroundColor: '#4a90e2',
              color: '#fff',
              border: 'none',
              padding: '1rem 2rem',
              borderRadius: '4px',
              fontSize: '1rem',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Refresh Page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
