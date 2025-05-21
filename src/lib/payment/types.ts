export interface PaymentProvider {
  id: string;
  name: string;
  displayName: string;
  iconUrl?: string;
  isActive: boolean;
  testMode: boolean;
  provider: 'stripe' | 'paypal';
}

export interface PaymentMethod {
  id: string;
  method: string;
  provider: string;
  gatewayId: string | null;
  testMode: boolean;
  displayName: string;
  iconUrl?: string;
}

export interface PaymentGatewayConfig {
  id: string;
  name: string;
  provider: string;
  apiKey: string;
  merchantId: string;
  webhookUrl: string;
  displayName: string;
  iconUrl?: string;
  isActive: boolean;
  testMode: boolean;
}