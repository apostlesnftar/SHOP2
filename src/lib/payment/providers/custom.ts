import { BasePaymentProvider } from './base';

export class CustomProvider extends BasePaymentProvider {
  private config: any;
  private implementation: any;

  constructor(config: any) {
    super({
      id: config.id,
      name: config.name,
      displayName: config.displayName,
      iconUrl: config.iconUrl,
      isActive: config.isActive,
      testMode: config.testMode,
      provider: 'custom'
    });
    this.config = config;
    
    // Load custom implementation
    if (config.code) {
      try {
        this.implementation = new Function('config', config.code)(config);
      } catch (error) {
        console.error('Failed to load custom provider implementation:', error);
      }
    }
  }

  async processPayment(amount: number, currency: string) {
    try {
      if (!this.implementation?.processPayment) {
        throw new Error('processPayment method not implemented');
      }

      return await this.implementation.processPayment(amount, currency);
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Payment failed'
      };
    }
  }

  async validateConfig() {
    try {
      if (!this.implementation?.validateConfig) {
        return {
          isValid: false,
          error: 'validateConfig method not implemented'
        };
      }

      return await this.implementation.validateConfig();
    } catch (error) {
      return {
        isValid: false,
        error: error instanceof Error ? error.message : 'Configuration validation failed'
      };
    }
  }

  async getPaymentMethods() {
    try {
      if (!this.implementation?.getPaymentMethods) {
        return [];
      }

      return await this.implementation.getPaymentMethods();
    } catch (error) {
      console.error('Error getting payment methods:', error);
      return [];
    }
  }
}