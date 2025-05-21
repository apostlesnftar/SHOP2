/*
  # Add code column to payment_gateways
  
  1. Changes
    - Add code column for custom provider implementation
    - Update functions to handle custom provider code
*/

-- Add code column to payment_gateways
ALTER TABLE payment_gateways
ADD COLUMN IF NOT EXISTS code text;

-- Update get_available_payment_methods function to handle custom providers
CREATE OR REPLACE FUNCTION get_available_payment_methods()
RETURNS TABLE (
  method text,
  provider text,
  gateway_id uuid,
  test_mode boolean,
  display_name text,
  icon_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN pg.provider = 'stripe' THEN 'credit_card'
      WHEN pg.provider = 'custom' THEN pg.name
      ELSE pg.provider
    END as method,
    pg.provider,
    pg.id as gateway_id,
    pg.test_mode,
    COALESCE(pg.display_name, 
      CASE 
        WHEN pg.provider = 'stripe' THEN 'Credit Card'
        WHEN pg.provider = 'paypal' THEN 'PayPal'
        ELSE pg.name
      END
    ) as display_name,
    pg.icon_url
  FROM payment_gateways pg
  WHERE pg.is_active = true
  UNION ALL
  SELECT 
    'friend_payment' as method,
    'internal' as provider,
    NULL as gateway_id,
    false as test_mode,
    'Split Payment' as display_name,
    NULL as icon_url;
END;
$$;

-- Update valid_provider constraint to allow custom providers
ALTER TABLE payment_gateways 
DROP CONSTRAINT IF EXISTS valid_provider;

ALTER TABLE payment_gateways
ADD CONSTRAINT valid_provider 
CHECK (provider IN ('stripe', 'paypal', 'custom'));