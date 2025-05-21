/*
  # Fix ambiguous referrer_id in payment webhook
  
  1. Changes
    - Update updateOrderStatus function to explicitly qualify the referrer_id column
    - Use table aliases to avoid ambiguity in the SQL query
    - Ensure proper column references in the join conditions
  
  2. Security
    - No changes to security policies
    - Function remains security definer to maintain existing permissions
*/

-- Update the updateOrderStatus function to use explicit table aliases
CREATE OR REPLACE FUNCTION update_order_status_webhook(
  p_order_number text,
  p_status text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_order_status text;
  v_payment_status text;
  v_payment_method text;
  v_user_id uuid;
  v_shared_order_id uuid;
  v_shared_order_referrer_id uuid;
BEGIN
  -- Find the order by order_number with explicit table aliases
  SELECT 
    o.id,
    o.status,
    o.payment_status,
    o.payment_method,
    o.user_id,
    so.id AS shared_order_id,
    so.referrer_id AS shared_order_referrer_id
  INTO 
    v_order_id,
    v_order_status,
    v_payment_status,
    v_payment_method,
    v_user_id,
    v_shared_order_id,
    v_shared_order_referrer_id
  FROM orders o
  LEFT JOIN shared_orders so ON so.order_id = o.id
  WHERE o.order_number = p_order_number
  LIMIT 1;
  
  -- Check if order exists
  IF v_order_id IS NULL THEN
    RAISE LOG 'Order not found: %', p_order_number;
    RETURN false;
  END IF;
  
  -- Log current order status
  RAISE LOG 'Current order status: %, payment status: %, payment method: %', 
    v_order_status, v_payment_status, v_payment_method;
  
  -- Map Acacia Pay status to our status
  IF p_status = 'SUCCESS' THEN
    v_order_status := 'processing';
    v_payment_status := 'completed';
    
    -- If this is a shared order, update its status too
    IF v_shared_order_id IS NOT NULL THEN
      UPDATE shared_orders
      SET 
        status = 'completed',
        updated_at = NOW()
      WHERE id = v_shared_order_id;
      
      RAISE LOG 'Updated shared order status to completed: %', v_shared_order_id;
    END IF;
    
  ELSIF p_status = 'FAIL' OR p_status = 'CLOSED' THEN
    v_order_status := 'cancelled';
    v_payment_status := 'failed';
  END IF;
  
  -- Update order status
  UPDATE orders
  SET
    status = v_order_status,
    payment_status = v_payment_status,
    updated_at = NOW()
  WHERE id = v_order_id;
  
  RAISE LOG 'Updated order % status to % and payment status to %', 
    v_order_id, v_order_status, v_payment_status;
  
  -- Create audit log
  INSERT INTO order_audit_logs (
    order_id,
    user_id,
    old_status,
    new_status,
    old_payment_status,
    new_payment_status,
    notes
  ) VALUES (
    v_order_id,
    v_user_id,
    v_order_status,
    v_order_status,
    v_payment_status,
    v_payment_status,
    'Payment webhook status update: ' || p_status
  );
  
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG 'Error in update_order_status_webhook: %', SQLERRM;
    RETURN false;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_order_status_webhook(text, text) TO service_role;