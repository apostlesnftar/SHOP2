/*
  # Add display_name and icon_url to payment methods function
  
  1. Changes
    - Update get_available_payment_methods function to include display_name and icon_url
    - Drop existing function first to avoid return type error
*/

-- First drop the existing function
DROP FUNCTION IF EXISTS get_available_payment_methods();

-- Create updated function with additional return columns
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_payment_methods() TO authenticated;