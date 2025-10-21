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
  updatedAt: Date;
}

export interface AddItemRequest {
  productId: string;
  name: string;
  price: number;
  quantity: number;
}

export interface UpdateItemRequest {
  quantity: number;
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}
