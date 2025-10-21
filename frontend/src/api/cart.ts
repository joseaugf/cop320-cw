import { cartApi } from './axios';

export interface CartItem {
  productId: string;
  name: string;
  price: number;
  quantity: number;
}

export interface Cart {
  sessionId: string;
  items: CartItem[];
  total: number;
}

export const getCart = async (): Promise<Cart> => {
  const response = await cartApi.get<Cart>('/api/cart');
  return response.data;
};

export const addToCart = async (
  productId: string,
  name: string,
  price: number,
  quantity: number
): Promise<Cart> => {
  const response = await cartApi.post<Cart>('/api/cart/items', {
    productId,
    name,
    price,
    quantity,
  });
  return response.data;
};

export const updateCartItem = async (
  productId: string,
  quantity: number
): Promise<Cart> => {
  const response = await cartApi.put<Cart>(`/api/cart/items/${productId}`, {
    quantity,
  });
  return response.data;
};

export const removeCartItem = async (productId: string): Promise<Cart> => {
  const response = await cartApi.delete<Cart>(`/api/cart/items/${productId}`);
  return response.data;
};

export const clearCart = async (): Promise<void> => {
  await cartApi.delete('/api/cart');
};
