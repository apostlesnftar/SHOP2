import { PaymentProvider } from '../types';

export abstract class BasePaymentProvider implements PaymentProvider {
  id: string;
  name: string;
  displayName: string;
  iconUrl?: string;
  isActive: boolean;
  testMode: boolean;
  provider: 'stripe' | 'paypal';

  constructor(config: PaymentProvider) {
    this.id = config.id;
    this.name = config.name;
    this.displayName = config.displayName;
    this.iconUrl = config.iconUrl;
    this.isActive = config.isActive;
    this.testMode = config.testMode;
    this.provider = config.provider;
  }

  abstract processPayment(amount: number, currency: string): Promise<{ success: boolean; transactionId?: string; error?: string }>;
  abstract validateConfig(): Promise<{ isValid: boolean; error?: string }>;
  abstract getPaymentMethods(): Promise<string[]>;
}

export { BasePaymentProvider }