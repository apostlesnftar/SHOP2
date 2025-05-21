import CryptoJS from 'crypto-js/md5';

/**
 * Generate MD5 hash (uppercase)
 * @param input - String to hash
 * @returns MD5 hash in uppercase
 */
export function md5(input: string): string {
  return CryptoJS(input).toString().toUpperCase();
}

/**
 * Generate Acacia Pay signature
 * @param params - Parameters to sign
 * @param merchantKey - Merchant key for signing
 * @returns Signature string
 */
export function generateAcaciaPaySignature(params: Record<string, any>, merchantKey: string): string {
  // Step 1: Sort parameters alphabetically
  const sortedParams = Object.keys(params)
    .filter(key => 
      key !== 'sign' && // Exclude sign parameter
      params[key] !== undefined && // Exclude undefined values
      params[key] !== null && // Exclude null values
      params[key] !== '' // Exclude empty strings
    )
    .sort()
    .reduce((acc: Record<string, any>, key) => {
      acc[key] = params[key];
      return acc;
    }, {});

  // Create string to sign
  const stringA = Object.entries(sortedParams)
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  // Add merchant key
  const stringSignTemp = `${stringA}&key=${merchantKey}`;
  
  // Generate MD5 hash
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

  const paramsWithoutSign = { ...params };
  delete paramsWithoutSign.sign;

  const calculatedSignature = generateAcaciaPaySignature(paramsWithoutSign, merchantKey);
  return calculatedSignature === signature;
}