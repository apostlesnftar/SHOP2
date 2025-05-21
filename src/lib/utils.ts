import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { nanoid } from 'nanoid';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(amount: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
  }).format(amount);
}

export function formatDate(date: string | Date | null | undefined): string {
  if (!date) return 'N/A';
  
  try {
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    }).format(new Date(date));
  } catch (error) {
    console.error('Error formatting date:', error);
    return 'Invalid date';
  }
}

export function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength)}...`;
}

export function generateOrderNumber(): string {
  return `ORD-${Math.floor(Math.random() * 1000000)}`;
}

export function generateShareId(): string {
  return nanoid(10);
}

export function calculateDiscount(price: number, discount: number): number {
  if (!discount) return price;
  return price - (price * discount) / 100;
}

export function debounce<T extends (...args: any[]) => any>(
  fn: T,
  ms = 300
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout>;
  
  return function(...args: Parameters<T>) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), ms);
  };
}

export function getInitials(name: string): string {
  return name
    .split(' ')
    .map(part => part[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

export function encryptOrderId(orderId: string): string {
  // In a real app, use proper encryption
  return Buffer.from(orderId).toString('base64');
}

export function decryptOrderId(encryptedId: string): string {
  // In a real app, use proper decryption
  return Buffer.from(encryptedId, 'base64').toString();
}

export function generateShareableLink(shareId: string): string {
  const baseUrl = import.meta.env.VITE_APP_URL || window.location.origin;
  return `${baseUrl}/shared-order/${shareId}`;
}