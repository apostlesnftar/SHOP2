import { User, Product } from './base-types';

// Order related types
export interface CartItem {
  productId: string;
  product: Product;
  quantity: number;
}

export interface Order {
  id: string;
  orderNumber: string;
  userId: string;
  items: OrderItem[];
  status: OrderStatus;
  shippingAddressId: string;
  paymentMethod: string;
  paymentStatus: PaymentStatus;
  subtotal: number;
  tax: number;
  shipping: number;
  total: number;
  shareId?: string; // Unique ID for sharing
  createdAt: string;
  updatedAt: string;
  trackingNumber?: string;
}

export interface OrderItem {
  id: string;
  orderId: string;
  productId: string;
  product: Product;
  quantity: number;
  price: number;
}

export interface SharedOrder {
  shareId: string;
  orderId: string;
  items: OrderItem[];
  total: number;
  status: OrderStatus;
  paymentStatus: PaymentStatus;
  expiresAt: string;
}

export type OrderStatus = 'pending' | 'processing' | 'shipped' | 'delivered' | 'cancelled';
export type PaymentStatus = 'pending' | 'processing' | 'completed' | 'failed' | 'refunded';

// Payment related types
export interface Payment {
  id: string;
  orderId: string;
  amount: number;
  method: string;
  status: PaymentStatus;
  transactionId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface GroupPayment {
  id: string;
  orderId: string;
  initiatorId: string;
  totalAmount: number;
  contributions: PaymentContribution[];
  expiresAt: string;
  createdAt: string;
  status: 'pending' | 'completed' | 'expired';
}

export interface PaymentContribution {
  id: string;
  groupPaymentId: string;
  userId?: string;
  email?: string;
  amount: number;
  status: 'pending' | 'paid' | 'cancelled';
  paymentId?: string;
}