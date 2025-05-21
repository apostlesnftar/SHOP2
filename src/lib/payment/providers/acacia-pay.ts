import { BasePaymentProvider } from './base';
import { generateAcaciaPaySignature } from '../utils/acacia-pay';

// Constants for Acacia Pay
export const ACACIA_PAY_MERCHANT_KEY = "Qc7ZCAAu63h2iMqwmDTjEizSDKejYIQPaKKofBC2ylmwgOts3iMvh8z9hughwvYxeod9bixBzrPgiVG6qC6QE91cEJaV47R6pyf9g4chXBWoZgLw27ZWzuO3nyX5KGi8";
export const ACACIA_PAY_API_URL = "https://mgr.jeepay.store/api/anon/pay/unifiedOrder";
export const ACACIA_PAY_MERCHANT_NO = "M1747068935";
export const ACACIA_PAY_APP_ID = "68222807cc36d1a5266b8589";

export class AcaciaPayProvider extends BasePaymentProvider {
  private apiKey: string; // mchNo
  private appId: string; // merchantId
  private webhookUrl: string;

  constructor(config: any) {
    super({
      id: config.id || 'acacia-pay',
      name: config.name || 'Acacia Pay',
      displayName: config.displayName || 'Acacia Pay',
      iconUrl: config.iconUrl,
      isActive: config.isActive !== undefined ? config.isActive : true,
      testMode: config.testMode !== undefined ? config.testMode : false,
      provider: 'custom' as any
    });
    
    this.apiKey = config.apiKey || ACACIA_PAY_MERCHANT_NO;
    this.appId = config.merchantId || ACACIA_PAY_APP_ID;
    this.webhookUrl = config.webhook_url || ACACIA_PAY_API_URL;
  }

  async processPayment(amount: number, currency: string) {
    try {
      // Validate amount range
      const amountInCents = Math.round(amount * 100); // Convert to cents
      if (amountInCents < 500 || amountInCents > 10000000) {
        console.error(`Invalid amount: ${amount} (${amountInCents} cents)`);
        return {
          success: false,
          error: 'Amount must be between ¥5.00 and ¥100,000.00'
        };
      }

      // Generate unique order number
      const mchOrderNo = `M${Date.now()}${Math.random().toString(36).slice(2, 8)}`;

      // Prepare order data
      const orderData: Record<string, any> = {
        mchNo: this.apiKey,
        wayCode: 'ACACIA_PAY',
        appId: this.appId,
        mchOrderNo,
        successUrl: `${window.location.origin}/payment/success`,
        subject: 'Payment',
        totalAmount: amountInCents,
        desc: 'Payment description',
        notifyUrl: `${window.location.origin}/api/payment/webhook`
      };

      // Add signature
      orderData.sign = generateAcaciaPaySignature(orderData, ACACIA_PAY_MERCHANT_KEY);
      
      console.log('Sending payment request to Acacia Pay:', JSON.stringify(orderData));

      // Make API request to the production endpoint
      const response = await fetch(this.webhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(orderData)
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error('Acacia Pay API error:', errorText);
        throw new Error(`HTTP error! status: ${response.status}, response: ${errorText}`);
      }

      const result = await response.json();
      console.log('Acacia Pay API response:', JSON.stringify(result));
      
      if (result.code !== 0) {
        return {
          success: false,
          error: result.msg || 'Payment failed',
          errorCode: result.code
        };
      }

      // Handle successful response - use payData as the payment URL
      return {
        success: true,
        transactionId: result.data.payOrderId,
        orderNumber: result.data.mchOrderNo,
        paymentUrl: result.data.payData,
        orderState: result.data.orderState
      };
    } catch (error) {
      console.error('Payment processing error:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Payment failed'
      };
    }
  }

  async validateConfig() {
    try {
      if (!this.apiKey || !/^M\d+$/.test(this.apiKey)) {
        return {
          isValid: false,
          error: 'Invalid Merchant ID (mchNo) format'
        };
      }

      if (!this.appId) {
        return {
          isValid: false,
          error: 'App ID is required'
        };
      }

      if (!this.webhookUrl) {
        return {
          isValid: false,
          error: 'API URL is required'
        };
      }

      return { isValid: true };
    } catch (error) {
      return {
        isValid: false,
        error: error instanceof Error ? error.message : 'Configuration validation failed'
      };
    }
  }

  async getPaymentMethods() {
    // Return the supported payment methods
    return ['acacia_pay'];
  }
}