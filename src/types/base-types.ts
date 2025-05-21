// User Types
export interface User {
  id: string;
  username: string;
  email?: string;
  fullName?: string;
  profileImage?: string;
  phone?: string;
  role: 'customer' | 'agent' | 'admin';
  createdAt: string;
}

// Product Types
export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  images: string[];
  categoryId: string;
  inventory: number;
  discount?: number;
  featured?: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Category {
  id: string;
  name: string;
  description: string;
  imageUrl: string;
  createdAt?: string;
  updatedAt?: string;
}

// Agent Types
export interface Agent {
  userId: string;
  level: number;
  parentAgentId?: string;
  commissionRate: number;
  totalEarnings: number;
  currentBalance: number;
  status: 'pending' | 'active' | 'suspended' | 'inactive';
  createdAt?: string;
  updatedAt?: string;
}

export interface Commission {
  id: string;
  agentId: string;
  orderId: string;
  amount: number;
  status: 'pending' | 'paid' | 'cancelled';
  createdAt: string;
  paidAt?: string;
}

// Address Type
export interface Address {
  id: string;
  userId: string;
  name: string;
  addressLine1: string;
  addressLine2?: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
  phone: string;
  isDefault: boolean;
  createdAt?: string;
  updatedAt?: string;
}