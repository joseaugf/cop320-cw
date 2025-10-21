import axios from 'axios';
import { injectTraceContext } from '../tracing';

const catalogApi = axios.create({
  baseURL: import.meta.env.VITE_API_CATALOG_URL || '',
  timeout: 10000,
});

const cartApi = axios.create({
  baseURL: import.meta.env.VITE_API_CART_URL || '',
  timeout: 10000,
});

const checkoutApi = axios.create({
  baseURL: import.meta.env.VITE_API_CHECKOUT_URL || '',
  timeout: 10000,
});

const featureFlagApi = axios.create({
  baseURL: import.meta.env.VITE_API_FEATURE_FLAG_URL || '',
  timeout: 10000,
});

// Generate or retrieve session ID
const getSessionId = (): string => {
  let sessionId = localStorage.getItem('sessionId');
  if (!sessionId) {
    sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    localStorage.setItem('sessionId', sessionId);
  }
  return sessionId;
};

// Add trace context propagation to all API clients
const apis = [catalogApi, cartApi, checkoutApi, featureFlagApi];

apis.forEach((api) => {
  api.interceptors.request.use((config) => {
    // Inject OpenTelemetry trace context
    const headersWithTrace = injectTraceContext(config.headers as Record<string, string>);
    config.headers = headersWithTrace as any;
    return config;
  });
});

// Add session ID to cart and checkout requests
cartApi.interceptors.request.use((config) => {
  config.headers['X-Session-Id'] = getSessionId();
  return config;
});

checkoutApi.interceptors.request.use((config) => {
  config.headers['X-Session-Id'] = getSessionId();
  return config;
});

export { catalogApi, cartApi, checkoutApi, featureFlagApi, getSessionId };
