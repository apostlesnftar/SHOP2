import { supabase } from '../lib/supabase';
import { PaymentProviderFactory } from '../lib/payment/factory';
import type { PaymentMethod, PaymentGatewayConfig } from '../lib/payment/types';

export async function getAvailablePaymentMethods(): Promise<PaymentMethod[]> {
  try {
    const { data, error } = await supabase.rpc('get_available_payment_methods');
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching payment methods:', error);
    throw error;
  }
}

export async function getSharedOrderPaymentMethods(): Promise<PaymentMethod[]> {
  try {
    const { data, error } = await supabase.rpc('get_shared_order_payment_methods');
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching shared order payment methods:', error);
    throw error;
  }
}

export async function validatePaymentGateway(config: PaymentGatewayConfig) {
  try {
    const provider = PaymentProviderFactory.createProvider(config);
    return await provider.validateConfig();
  } catch (error) {
    return {
      isValid: false,
      error: error instanceof Error ? error.message : 'Failed to validate payment gateway'
    };
  }
}

export async function testPaymentGateway(gatewayId: string) {
  try {
    // Get gateway config
    const { data: config, error } = await supabase
      .from('payment_gateways')
      .select('*')
      .eq('id', gatewayId)
      .single();
    
    if (error) throw error;
    if (!config) throw new Error('Payment gateway not found');

    // Create provider instance
    const provider = PaymentProviderFactory.createProvider(config);
    
    // Test configuration
    const validationResult = await provider.validateConfig();
    if (!validationResult.isValid) {
      throw new Error(validationResult.error);
    }

    // Test payment processing with a minimal amount
    const testResult = await provider.processPayment(1, 'USD');
    if (!testResult.success) {
      throw new Error(testResult.error);
    }

    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Connection test failed'
    };
  }
}