/*
  # Payment Gateway Functions
  
  1. Functions
    - get_available_payment_methods - Get list of active payment methods
    - is_valid_payment_method - Validate payment method
*/

-- Function to get available payment methods
CREATE OR REPLACE FUNCTION get_available_payment_methods()
RETURNS TABLE (
  method text,
  provider text,
  gateway_id uuid,
  test_mode boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN pg.provider = 'stripe' THEN 'credit_card'
      ELSE pg.provider
    END as method,
    pg.provider,
    pg.id as gateway_id,
    pg.test_mode
  FROM payment_gateways pg
  WHERE pg.is_active = true
  UNION ALL
  SELECT 
    'friend_payment' as method,
    'internal' as provider,
    NULL as gateway_id,
    false as test_mode;
END;
$$;

-- Function to validate payment method
CREATE OR REPLACE FUNCTION is_valid_payment_method(method text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Friend payment is always valid
  IF method = 'friend_payment' THEN
    RETURN true;
  END IF;
  
  -- Check if method exists in active gateways
  RETURN EXISTS (
    SELECT 1 
    FROM payment_gateways 
    WHERE 
      is_active = true AND
      CASE 
        WHEN provider = 'stripe' THEN 'credit_card'
        ELSE provider
      END = method
  );
END;
$$;

-- Grant access to functions
GRANT EXECUTE ON FUNCTION get_available_payment_methods() TO authenticated;
GRANT EXECUTE ON FUNCTION is_valid_payment_method(text) TO authenticated;