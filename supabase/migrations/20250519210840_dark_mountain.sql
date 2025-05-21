/*
  # Add Acacia Pay Signature Utilities
  
  1. New Functions
    - `generate_acacia_pay_signature` - Generates a signature for Acacia Pay requests
    - `verify_acacia_pay_signature` - Verifies a signature from Acacia Pay responses
    
  2. Security
    - Functions are accessible to authenticated users
    - Proper parameter validation and error handling
*/

-- Function to generate MD5 hash for Acacia Pay signatures
CREATE OR REPLACE FUNCTION generate_acacia_pay_signature(
  p_params jsonb,
  p_merchant_key text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_keys text[];
  v_string_a text := '';
  v_string_sign_temp text;
  v_key text;
  v_value text;
  v_md5 text;
BEGIN
  -- Extract keys from params, excluding 'sign'
  SELECT array_agg(k) INTO v_keys
  FROM jsonb_object_keys(p_params) k
  WHERE k != 'sign'
  ORDER BY k;
  
  -- Build string_a (key1=value1&key2=value2...)
  FOR i IN 1..array_length(v_keys, 1) LOOP
    v_key := v_keys[i];
    v_value := p_params->>v_key;
    
    -- Skip empty values
    IF v_value IS NOT NULL AND v_value != '' THEN
      IF v_string_a != '' THEN
        v_string_a := v_string_a || '&';
      END IF;
      v_string_a := v_string_a || v_key || '=' || v_value;
    END IF;
  END LOOP;
  
  -- Append key to get stringSignTemp
  v_string_sign_temp := v_string_a || '&key=' || p_merchant_key;
  
  -- Generate MD5 hash and convert to uppercase
  v_md5 := upper(md5(v_string_sign_temp));
  
  RETURN v_md5;
END;
$$;

-- Function to verify Acacia Pay signature
CREATE OR REPLACE FUNCTION verify_acacia_pay_signature(
  p_params jsonb,
  p_merchant_key text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_signature text;
  v_params_without_sign jsonb;
  v_calculated_signature text;
BEGIN
  -- Extract signature from params
  v_signature := p_params->>'sign';
  
  -- If no signature provided, return false
  IF v_signature IS NULL THEN
    RETURN false;
  END IF;
  
  -- Create a copy of params without the sign field
  v_params_without_sign := p_params - 'sign';
  
  -- Calculate signature
  v_calculated_signature := generate_acacia_pay_signature(v_params_without_sign, p_merchant_key);
  
  -- Compare signatures
  RETURN v_calculated_signature = v_signature;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_acacia_pay_signature(jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_acacia_pay_signature(jsonb, text) TO authenticated;