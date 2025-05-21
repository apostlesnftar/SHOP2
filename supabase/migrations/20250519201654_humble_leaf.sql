/*
  # Add payment gateway display info to functions
  
  1. Changes
    - Update get_available_payment_methods function to include display_name and icon_url
    - Update get_shared_order_payment_methods function to include display_name and icon_url
    - Fix log_payment_gateway_changes function to handle user_id properly
*/

-- First drop the existing functions
DROP FUNCTION IF EXISTS get_available_payment_methods();
DROP FUNCTION IF EXISTS get_shared_order_payment_methods();

-- Create updated function with display_name and icon_url
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

-- Create updated shared order payment methods function
CREATE OR REPLACE FUNCTION get_shared_order_payment_methods()
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
  -- Only return active payment gateways, excluding friend_payment
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
  WHERE pg.is_active = true;
END;
$$;

-- Fix the log_payment_gateway_changes function to handle NULL user_id
CREATE OR REPLACE FUNCTION log_payment_gateway_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
  v_changes jsonb;
BEGIN
  -- Get the current user ID or use a system user ID if not available
  v_user_id := COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);
  
  IF TG_OP = 'INSERT' THEN
    v_changes := jsonb_build_object(
      'name', NEW.name,
      'provider', NEW.provider,
      'is_active', NEW.is_active,
      'test_mode', NEW.test_mode,
      'display_name', NEW.display_name,
      'icon_url', NEW.icon_url
    );
    
    INSERT INTO payment_gateway_logs (gateway_id, user_id, action, changes)
    VALUES (NEW.id, v_user_id, 'created', v_changes);
  ELSIF TG_OP = 'UPDATE' THEN
    v_changes := jsonb_build_object(
      'name', CASE WHEN NEW.name <> OLD.name THEN NEW.name ELSE null END,
      'provider', CASE WHEN NEW.provider <> OLD.provider THEN NEW.provider ELSE null END,
      'is_active', CASE WHEN NEW.is_active <> OLD.is_active THEN NEW.is_active ELSE null END,
      'test_mode', CASE WHEN NEW.test_mode <> OLD.test_mode THEN NEW.test_mode ELSE null END,
      'display_name', CASE WHEN NEW.display_name <> OLD.display_name THEN NEW.display_name ELSE null END,
      'icon_url', CASE WHEN COALESCE(NEW.icon_url, '') <> COALESCE(OLD.icon_url, '') THEN NEW.icon_url ELSE null END
    ) - 'null';
    
    INSERT INTO payment_gateway_logs (gateway_id, user_id, action, changes)
    VALUES (NEW.id, v_user_id, 'updated', v_changes);
  ELSIF TG_OP = 'DELETE' THEN
    v_changes := jsonb_build_object(
      'name', OLD.name,
      'provider', OLD.provider,
      'display_name', OLD.display_name
    );
    
    INSERT INTO payment_gateway_logs (gateway_id, user_id, action, changes)
    VALUES (OLD.id, v_user_id, 'deleted', v_changes);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS payment_gateway_audit ON payment_gateways;
CREATE TRIGGER payment_gateway_audit
  AFTER INSERT OR UPDATE OR DELETE ON payment_gateways
  FOR EACH ROW EXECUTE FUNCTION log_payment_gateway_changes();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_available_payment_methods() TO authenticated;
GRANT EXECUTE ON FUNCTION get_shared_order_payment_methods() TO authenticated;