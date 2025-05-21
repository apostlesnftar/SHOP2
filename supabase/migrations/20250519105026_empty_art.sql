/*
  # Fix share_order function parameters
  
  1. Changes
    - Update share_order function to handle parameters in correct order
    - Add validation for order ownership
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS share_order(INTEGER, UUID);
DROP FUNCTION IF EXISTS share_order(UUID, INTEGER);

-- Recreate the function with proper parameter order and validation
CREATE OR REPLACE FUNCTION share_order(
  p_order_id UUID,
  p_expiry_hours INTEGER DEFAULT 24
) RETURNS TEXT AS $$
DECLARE
  v_share_id TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Validate order exists and belongs to the current user
  IF NOT EXISTS (
    SELECT 1 FROM orders
    WHERE id = p_order_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Order not found or access denied';
  END IF;
  
  -- Generate a random share ID
  v_share_id := SUBSTR(MD5(p_order_id::TEXT || NOW()::TEXT), 1, 12);
  v_expires_at := NOW() + (p_expiry_hours || ' hours')::INTERVAL;
  
  -- Create the shared order record
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    v_expires_at
  );
  
  RETURN v_share_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;