import { md5 } from './md5';

/**
 * Acacia Pay merchant key for signature generation
 */
export const ACACIA_PAY_MERCHANT_KEY = "Qc7ZCAAu63h2iMqwmDTjEizSDKejYIQPaKKofBC2ylmwgOts3iMvh8z9hughwvYxeod9bixBzrPgiVG6qC6QE91cEJaV47R6pyf9g4chXBWoZgLw27ZWzuO3nyX5KGi8";

/**
 * Acacia Pay API URL
 */
export const ACACIA_PAY_API_URL = "https://mgr.jeepay.store/api/anon/pay/unifiedOrder";

/**
 * Acacia Pay merchant number
 */
export const ACACIA_PAY_MERCHANT_NO = "M1747068935";

/**
 * Acacia Pay app ID
 */
export const ACACIA_PAY_APP_ID = "68222807cc36d1a5266b8589";

/**
 * Generate signature for Acacia Pay
 * @param params - Parameters to sign
 * @param merchantKey - Merchant key for signing
 * @returns Signature string
 */
export function generateAcaciaPaySignature(params: Record<string, any>, merchantKey: string): string {
  // Step 1: Sort parameters alphabetically by parameter name (ASCII/dictionary order)
  const sortedParams = Object.keys(params)
    .filter(key => {
      // Skip sign parameter and empty values
      if (key === 'sign') return false;
      if (params[key] === undefined || params[key] === null || params[key] === '') return false;
      return true;
    })
    .sort() // Sort alphabetically
    .reduce((acc: Record<string, any>, key) => {
      acc[key] = params[key];
      return acc;
    }, {});

  // Create URL key-value string (key1=value1&key2=value2...)
  const stringA = Object.entries(sortedParams)
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  // Step 2: Append key to the end of stringA
  const stringSignTemp = `${stringA}&key=${merchantKey}`;

  // Perform MD5 hash and convert to uppercase
  console.log('String to sign:', stringSignTemp);
  return md5(stringSignTemp);
}

/**
 * Verify Acacia Pay signature
 * @param params - Parameters including the signature
 * @param merchantKey - Merchant key for verification
 * @returns Boolean indicating if signature is valid
 */
export function verifyAcaciaPaySignature(
  params: Record<string, any>, 
  merchantKey: string
): boolean {
  const signature = params.sign;
  if (!signature) return false;
  
  // Create a copy of params without the sign field
  const paramsWithoutSign = { ...params };
  delete paramsWithoutSign.sign;
  
  // Generate signature and compare
  const calculatedSignature = generateAcaciaPaySignature(paramsWithoutSign, merchantKey);
  return calculatedSignature === signature;
}

/**
 * Create an Acacia Pay order
 * @param amount - Amount in yuan (will be converted to cents)
 * @param orderNumber - Optional order number (will be generated if not provided)
 * @param options - Additional options for the order
 * @returns Order creation result
 */
export async function createAcaciaPayOrder(
  amount: number,
  orderNumber?: string,
  options?: {
    successUrl?: string;
    notifyUrl?: string;
    subject?: string;
    description?: string;
  }
): Promise<{
  success: boolean;
  paymentUrl?: string;
  transactionId?: string;
  orderNumber?: string;
  error?: string;
}> {
  try {
    // Validate amount range
    const amountInCents = Math.round(amount * 100); // Convert to cents
    if (amountInCents < 500 || amountInCents > 10000000) {
      return {
        success: false,
        error: 'Amount must be between ¥5.00 and ¥100,000.00'
      };
    }

    // Generate unique order number if not provided
    const mchOrderNo = orderNumber || `M${Date.now()}${Math.random().toString(36).slice(2, 8)}`;

    const { successUrl, notifyUrl, subject, description } = options || {};

    // Prepare order data
    const orderData: Record<string, any> = {
      mchNo: ACACIA_PAY_MERCHANT_NO,
      wayCode: 'ACACIA_PAY',
      appId: ACACIA_PAY_APP_ID,
      mchOrderNo,
      subject: subject || 'Payment',
      totalAmount: amountInCents,
      desc: description || 'Payment description',
      notifyUrl: notifyUrl || `${window.location.origin}/api/payment/webhook`
    };

    // Add success URL if provided
    if (successUrl) {
      orderData.successUrl = successUrl;
    }

    // Add signature
    orderData.sign = generateAcaciaPaySignature(orderData, ACACIA_PAY_MERCHANT_KEY);

    console.log('Sending payment request to Acacia Pay:', JSON.stringify(orderData));

    // Make API request
    const response = await fetch(ACACIA_PAY_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(orderData)
    });

    // Handle API response
    if (!response.ok) {
      const errorText = await response.text();
      console.error('Acacia Pay API error:', errorText);
      throw new Error(`HTTP error! status: ${response.status}, response: ${errorText}`);
    }

    const result = await response.json();
    console.log('Acacia Pay API response:', JSON.stringify(result));

    if (!result || result.code !== 0) {
      return {
        success: false,
        error: result.msg || 'Payment failed',
        orderNumber: mchOrderNo
      };
    }

    // Handle successful response - use payData as the payment URL
    return {
      success: true,
      transactionId: result.data.payOrderId,
      orderNumber: result.data.mchOrderNo || mchOrderNo,
      paymentUrl: result.data.payData
    };
  } catch (error) {
    console.error('Payment processing error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Payment failed'
    };
  }
}