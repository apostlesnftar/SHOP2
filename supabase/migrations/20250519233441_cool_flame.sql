/*
  # Fix order_audit_logs user_id constraint violation
  
  1. Changes
    - Update create_order_audit_log function to handle null auth.uid()
    - Get user_id from the orders table instead of auth.uid()
    - Ensure order status changes are properly logged even when triggered by system processes
*/

-- Function to create order audit log with user_id from orders table
CREATE OR REPLACE FUNCTION create_order_audit_log()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the user_id from the orders table instead of auth.uid()
  SELECT user_id INTO v_user_id FROM orders WHERE id = NEW.id;

  -- If user_id is still null (shouldn't happen), use a system user ID
  IF v_user_id IS NULL THEN
    v_user_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  INSERT INTO order_audit_logs (
    order_id,
    user_id,
    old_status,
    new_status,
    old_payment_status,
    new_payment_status,
    notes
  ) VALUES (
    NEW.id,
    v_user_id,
    OLD.status,
    NEW.status,
    OLD.payment_status,
    NEW.payment_status,
    CASE
      WHEN NEW.status = 'processing' THEN 'Order confirmed and processing started'
      WHEN NEW.status = 'shipped' THEN 'Order shipped - Tracking: ' || COALESCE(NEW.tracking_number, 'N/A')
      WHEN NEW.status = 'delivered' THEN 'Order delivered'
      WHEN NEW.status = 'cancelled' THEN 'Order cancelled'
      ELSE NULL
    END
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate the trigger to ensure it uses the updated function
DROP TRIGGER IF EXISTS log_order_status_changes ON orders;

CREATE TRIGGER log_order_status_changes
  AFTER UPDATE OF status, payment_status ON orders
  FOR EACH ROW
  WHEN (
    NEW.status IS DISTINCT FROM OLD.status OR 
    NEW.payment_status IS DISTINCT FROM OLD.payment_status
  )
  EXECUTE FUNCTION create_order_audit_log();