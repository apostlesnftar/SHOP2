/*
  # Fix system user creation and payment gateway logging
  
  1. Changes
    - Add proper checks before creating system user
    - Update payment gateway logging function
    - Fix trigger recreation
*/

-- First check and update existing system user profile
DO $$
DECLARE
  v_system_user_id uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  -- Update profile if it exists, otherwise create it
  UPDATE user_profiles
  SET 
    role = 'admin',
    username = 'System',
    updated_at = NOW()
  WHERE id = v_system_user_id;
  
  -- Only try to create the auth user if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_system_user_id) THEN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_system_user_id,
      'authenticated',
      'authenticated',
      'system@example.com',
      '{"provider": "system", "providers": ["system"]}',
      '{"role": "admin"}',
      NOW(),
      NOW()
    );
  END IF;
END $$;

-- Update the log_payment_gateway_changes function to handle NULL user_id
CREATE OR REPLACE FUNCTION log_payment_gateway_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
  v_changes jsonb;
BEGIN
  -- Get the current user ID or use the system user ID if not available
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
      'display_name', CASE WHEN COALESCE(NEW.display_name, '') <> COALESCE(OLD.display_name, '') THEN NEW.display_name ELSE null END,
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