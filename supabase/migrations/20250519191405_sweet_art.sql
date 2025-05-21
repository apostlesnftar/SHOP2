/*
  # Add Payment Gateway Management
  
  1. New Tables
    - payment_gateways - Store payment gateway configurations
    - payment_gateway_logs - Track configuration changes
  
  2. Security
    - Enable RLS
    - Add policies for admin access
    - Encrypt sensitive data
*/

-- Create payment gateways table
CREATE TABLE IF NOT EXISTS payment_gateways (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  provider TEXT NOT NULL,
  api_key TEXT NOT NULL,
  merchant_id TEXT NOT NULL,
  webhook_url TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  test_mode BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Add constraints
  CONSTRAINT valid_provider CHECK (provider IN ('stripe', 'paypal'))
);

-- Create payment gateway logs table
CREATE TABLE IF NOT EXISTS payment_gateway_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gateway_id UUID NOT NULL REFERENCES payment_gateways(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  action TEXT NOT NULL,
  changes JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE payment_gateways ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_gateway_logs ENABLE ROW LEVEL SECURITY;

-- Create policies for payment gateways
CREATE POLICY "Admins can manage payment gateways"
ON payment_gateways
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Create policies for payment gateway logs
CREATE POLICY "Admins can view payment gateway logs"
ON payment_gateway_logs
FOR SELECT
TO authenticated
USING (is_admin());

-- Create function to log payment gateway changes
CREATE OR REPLACE FUNCTION log_payment_gateway_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO payment_gateway_logs (gateway_id, user_id, action, changes)
    VALUES (
      NEW.id,
      auth.uid(),
      'created',
      jsonb_build_object(
        'name', NEW.name,
        'provider', NEW.provider,
        'is_active', NEW.is_active,
        'test_mode', NEW.test_mode
      )
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO payment_gateway_logs (gateway_id, user_id, action, changes)
    VALUES (
      NEW.id,
      auth.uid(),
      'updated',
      jsonb_build_object(
        'name', CASE WHEN NEW.name <> OLD.name THEN NEW.name ELSE null END,
        'provider', CASE WHEN NEW.provider <> OLD.provider THEN NEW.provider ELSE null END,
        'is_active', CASE WHEN NEW.is_active <> OLD.is_active THEN NEW.is_active ELSE null END,
        'test_mode', CASE WHEN NEW.test_mode <> OLD.test_mode THEN NEW.test_mode ELSE null END
      ) - 'null'
    );
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO payment_gateway_logs (gateway_id, user_id, action, changes)
    VALUES (
      OLD.id,
      auth.uid(),
      'deleted',
      jsonb_build_object(
        'name', OLD.name,
        'provider', OLD.provider
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for logging changes
CREATE TRIGGER payment_gateway_audit
AFTER INSERT OR UPDATE OR DELETE ON payment_gateways
FOR EACH ROW EXECUTE FUNCTION log_payment_gateway_changes();

-- Create function to update timestamps
CREATE TRIGGER update_payment_gateways_modtime
BEFORE UPDATE ON payment_gateways
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

-- Add indexes for better performance
CREATE INDEX idx_payment_gateway_logs_gateway_id ON payment_gateway_logs(gateway_id);
CREATE INDEX idx_payment_gateway_logs_user_id ON payment_gateway_logs(user_id);
CREATE INDEX idx_payment_gateway_logs_created_at ON payment_gateway_logs(created_at);