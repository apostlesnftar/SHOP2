/*
  # Add payment gateway display customization
  
  1. Changes
    - Add display_name and icon_url columns to payment_gateways
    - Update get_available_payment_methods function to include display info
*/

-- Add new columns to payment_gateways
ALTER TABLE payment_gateways
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS icon_url TEXT;

-- Drop existing function first
DROP FUNCTION IF EXISTS get_available_payment_methods();

-- Recreate function with updated return type
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