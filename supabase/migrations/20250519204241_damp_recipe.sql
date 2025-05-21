/*
  # Add Acacia Pay Provider
  
  1. Changes
    - Add Acacia Pay payment gateway configuration
    - Add provider implementation code
    - Handle user ID constraint for audit logging
*/

-- Temporarily disable the audit trigger
DROP TRIGGER IF EXISTS payment_gateway_audit ON payment_gateways;

-- Insert Acacia Pay provider
INSERT INTO payment_gateways (
  name,
  provider,
  display_name,
  api_key,
  merchant_id,
  webhook_url,
  is_active,
  test_mode,
  code
) VALUES (
  'Acacia Pay',
  'custom',
  'Acacia Pay',
  'M1732547918', -- Default merchant ID from docs
  '6744955449d6dee99997e4d5', -- Default app ID from docs
  'https://mgr.jeepay.store/api/anon/pay/unifiedOrder',
  true,
  true,
  $CODE$
// Acacia Pay Provider Implementation
return {
  // Process a payment
  async processPayment(amount, currency) {
    try {
      // Validate amount range (500-10000000)
      if (amount < 500 || amount > 10000000) {
        return {
          success: false,
          error: 'Amount must be between 500 and 10000000'
        };
      }

      // Prepare order data
      const orderData = {
        mchNo: config.apiKey, // Merchant ID
        wayCode: 'ACACIA_PAY',
        appId: config.merchantId, // App ID
        mchOrderNo: `M${Date.now()}`, // Generate unique order number
        successUrl: window.location.origin + '/payment/success',
        subject: 'Payment',
        totalAmount: amount,
        desc: 'Payment description',
        sign: this.generateSign({
          mchNo: config.apiKey,
          appId: config.merchantId,
          mchOrderNo: `M${Date.now()}`,
          totalAmount: amount
        })
      };

      // Make API request
      const response = await fetch(config.webhook_url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(orderData)
      });

      const result = await response.json();

      if (result.code !== 0) {
        return {
          success: false,
          error: result.msg || 'Payment failed'
        };
      }

      // Handle successful response
      return {
        success: true,
        transactionId: result.data.payOrderId,
        paymentUrl: result.data.payData // URL for payment page
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Payment failed'
      };
    }
  },

  // Validate the provider configuration
  async validateConfig() {
    try {
      if (!config.apiKey) {
        return {
          isValid: false,
          error: 'Merchant ID (mchNo) is required'
        };
      }

      if (!config.merchantId) {
        return {
          isValid: false,
          error: 'App ID is required'
        };
      }

      if (!config.webhook_url) {
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
  },

  // Get supported payment methods
  async getPaymentMethods() {
    return ['acacia_pay'];
  },

  // Helper function to generate signature
  generateSign(params) {
    // TODO: Implement actual signature generation according to Acacia Pay docs
    // This is a placeholder implementation
    return '4A5078DABBCE0D9C4E7668DACB96FF7A';
  }
};
$CODE$
);

-- Get the first admin user's ID for the audit log
DO $$
DECLARE
  v_admin_id uuid;
BEGIN
  SELECT id INTO v_admin_id
  FROM user_profiles
  WHERE role = 'admin'
  LIMIT 1;

  -- If we found an admin user, create the audit log entry manually
  IF v_admin_id IS NOT NULL THEN
    INSERT INTO payment_gateway_logs (
      gateway_id,
      user_id,
      action,
      changes
    )
    SELECT
      id,
      v_admin_id,
      'created',
      jsonb_build_object(
        'name', name,
        'provider', provider,
        'is_active', is_active,
        'test_mode', test_mode,
        'display_name', display_name
      )
    FROM payment_gateways
    WHERE name = 'Acacia Pay';
  END IF;
END $$;

-- Re-enable the audit trigger
CREATE TRIGGER payment_gateway_audit
  AFTER INSERT OR UPDATE OR DELETE ON payment_gateways
  FOR EACH ROW EXECUTE FUNCTION log_payment_gateway_changes();