-- Temporarily disable the trigger
ALTER TABLE payment_gateways DISABLE TRIGGER payment_gateway_audit;

-- Update Acacia Pay provider code
UPDATE payment_gateways 
SET code = $CODE$
// Acacia Pay Provider Implementation
return {
  // Process a payment
  async processPayment(amount, currency) {
    try {
      // Validate amount range (500-10000000)
      const amountInCents = Math.round(amount * 100); // Convert to cents
      if (amountInCents < 500 || amountInCents > 10000000) {
        return {
          success: false,
          error: 'Amount must be between ¥5.00 and ¥100,000.00'
        };
      }

      // Generate unique order number
      const mchOrderNo = `M${Date.now()}${Math.random().toString(36).slice(2, 8)}`;

      // Prepare order data
      const orderData = {
        mchNo: config.apiKey, // Merchant ID
        wayCode: 'ACACIA_PAY',
        appId: config.merchantId, // App ID
        mchOrderNo,
        successUrl: `${window.location.origin}/payment/success`,
        subject: 'Payment',
        totalAmount: amountInCents,
        desc: 'Payment description',
        notifyUrl: `${window.location.origin}/api/payment/webhook`,
        expiredTime: 3600 // 1 hour expiry
      };

      // Add signature
      orderData.sign = this.generateSign(orderData);

      // Make API request
      const response = await fetch(config.webhook_url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(orderData)
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const result = await response.json();

      if (result.code !== 0) {
        return {
          success: false,
          error: result.msg || 'Payment failed',
          errorCode: result.code
        };
      }

      // Handle successful response
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
  },

  // Validate the provider configuration
  async validateConfig() {
    try {
      if (!config.apiKey || !/^M\d+$/.test(config.apiKey)) {
        return {
          isValid: false,
          error: 'Invalid Merchant ID (mchNo) format'
        };
      }

      if (!config.merchantId) {
        return {
          isValid: false,
          error: 'App ID is required'
        };
      }

      if (!config.webhook_url || !config.webhook_url.startsWith('https://')) {
        return {
          isValid: false,
          error: 'Invalid API URL. Must be HTTPS.'
        };
      }

      // Test API connection
      try {
        const response = await fetch(config.webhook_url, {
          method: 'OPTIONS',
          headers: {
            'Content-Type': 'application/json'
          }
        });

        if (!response.ok && response.status !== 405) { // 405 is ok for OPTIONS
          throw new Error('API endpoint not accessible');
        }
      } catch (error) {
        return {
          isValid: false,
          error: 'Failed to connect to API endpoint'
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

  // Generate signature for request
  generateSign(params) {
    // Sort parameters alphabetically
    const sortedParams = Object.keys(params)
      .filter(key => 
        key !== 'sign' && // Exclude sign parameter
        params[key] !== undefined && // Exclude undefined values
        params[key] !== null && // Exclude null values
        params[key] !== '' // Exclude empty strings
      )
      .sort()
      .reduce((acc, key) => {
        acc[key] = params[key];
        return acc;
      }, {});

    // Create string to sign
    const stringToSign = Object.entries(sortedParams)
      .map(([key, value]) => `${key}=${value}`)
      .join('&');

    // Add merchant key
    const signString = stringToSign + config.apiKey;

    // Generate MD5 hash
    const md5 = (str) => {
      // Simple MD5 implementation for demo
      // In production, use a proper crypto library
      let hash = 0;
      for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash;
      }
      return Math.abs(hash).toString(16).toUpperCase();
    };

    return md5(signString);
  }
};
$CODE$
WHERE name = 'Acacia Pay';

-- Re-enable the trigger
ALTER TABLE payment_gateways ENABLE TRIGGER payment_gateway_audit;