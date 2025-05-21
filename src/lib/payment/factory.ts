import { PaymentProvider, PaymentGatewayConfig } from './types';
import { StripeProvider } from './providers/stripe';
import { PayPalProvider } from './providers/paypal';
import { CustomProvider } from './providers/custom';
import { AcaciaPayProvider } from './providers/acacia-pay';

export class PaymentProviderFactory {
  static createProvider(config: PaymentGatewayConfig): PaymentProvider {
    switch (config.provider) {
      case 'stripe':
        return new StripeProvider(config);
      case 'paypal':
        return new PayPalProvider(config);
      case 'acacia_pay':
        return new AcaciaPayProvider(config);
      case 'custom':
        return new CustomProvider(config);
      default:
        throw new Error(`Unsupported payment provider: ${config.provider}`);
    }
  }

  static async getAvailableProviders(): Promise<string[]> {
    return ['stripe', 'paypal', 'acacia_pay', 'custom'];
  }
}