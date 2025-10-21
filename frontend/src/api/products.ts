import { catalogApi } from './axios';
import { Product } from '../types/product';

export const getProducts = async (): Promise<Product[]> => {
  const response = await catalogApi.get<Product[]>('/api/products');
  return response.data;
};

export const getProductById = async (id: string): Promise<Product> => {
  const response = await catalogApi.get<Product>(`/api/products/${id}`);
  return response.data;
};

export const searchProducts = async (query: string): Promise<Product[]> => {
  const response = await catalogApi.get<Product[]>('/api/products/search', {
    params: { q: query },
  });
  return response.data;
};
