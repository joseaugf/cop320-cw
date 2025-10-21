import { checkoutApi } from './axios';

export interface CartItem {
  productId: string;
  name: string;
  price: number;
  quantity: number;
}

export interface CheckoutRequest {
  customerEmail: string;
  shippingAddress: string;
  items?: CartItem[];
}

export interface Order {
  id: string;
  sessionId: string;
  customerEmail: string;
  shippingAddress: string;
  total: number;
  status: string;
  createdAt: string;
}

// Get or create session ID
const getSessionId = (): string => {
  let sessionId = localStorage.getItem('sessionId');
  if (!sessionId) {
    sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    localStorage.setItem('sessionId', sessionId);
  }
  return sessionId;
};

export const processCheckout = async (data: CheckoutRequest): Promise<Order> => {
  const sessionId = getSessionId();
  const response = await checkoutApi.post<Order>('/api/checkout', {
    session_id: sessionId,
    customer_email: data.customerEmail,
    shipping_address: data.shippingAddress,
  });
  return response.data;
};

export const getOrder = async (orderId: string): Promise<Order> => {
  const response = await checkoutApi.get<Order>(`/api/orders/${orderId}`);
  return response.data;
};
