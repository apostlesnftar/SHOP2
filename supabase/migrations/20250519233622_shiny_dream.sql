/*
  # Fix process_friend_payment function
  
  1. Changes
    - Update process_friend_payment function to handle user_id properly
    - Ensure order audit logs are created with valid user_id
    - Fix the null value in column "user_id" error
*/

-- Update process_friend_payment function to handle user_id properly
CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order_id uuid;
  v_order_number text;
  v_user_id uuid;
BEGIN
  -- Get shared order with user_id
  SELECT 
    s.*,
    o.order_number,
    o.id as order_id,
    o.user_id
  INTO v_shared_order
  FROM shared_orders s
  JOIN orders o ON o.id = s.order_id
  WHERE s.share_id = p_share_id
  AND s.expires_at > now()
  AND s.status = 'pending'
  AND o.payment_method = 'friend_payment'
  AND o.payment_status = 'pending';
  
  -- Validate shared order
  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found, expired, or already paid'
    );
  END IF;
  
  -- Validate payment method
  IF p_payment_method NOT IN ('credit_card', 'paypal', 'acacia_pay') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method'
    );
  END IF;
  
  -- Store user_id for audit log
  v_user_id := v_shared_order.user_id;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing'
  WHERE id = v_shared_order.order_id
  AND payment_status = 'pending'
  RETURNING id INTO v_order_id;
  
  -- If order was updated successfully
  IF v_order_id IS NOT NULL THEN
    -- Create audit log manually to ensure user_id is set
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
      'pending',
      'processing',
      'pending',
      'completed',
      'Order payment completed via shared payment link'
    );
    
    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE share_id = p_share_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'order_number', v_shared_order.order_number
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Failed to process payment'
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;