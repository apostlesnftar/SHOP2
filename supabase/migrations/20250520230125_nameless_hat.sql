/*
  # Fix ambiguous order_number reference

  1. Changes
    - Update process_friend_payment function to use qualified column names
    - Add explicit table references to order_number column to resolve ambiguity

  2. Technical Details
    - Modify the process_friend_payment function to use orders.order_number
    - Ensure all column references are properly qualified with their table names
*/

CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_total numeric(10,2);
  v_result jsonb;
BEGIN
  -- Get order details from shared order
  SELECT 
    so.order_id,
    o.total,
    o.user_id
  INTO 
    v_order_id,
    v_total,
    v_user_id
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
    AND so.status = 'pending'
    AND so.expires_at > now();

  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired shared order'
    );
  END IF;

  -- Update order payment method and status
  UPDATE orders
  SET 
    payment_method = p_payment_method,
    payment_status = 'processing',
    status = 'processing'
  WHERE id = v_order_id
  AND status = 'pending'
  RETURNING orders.order_number
  INTO v_result;

  IF v_result IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Failed to update order status'
    );
  END IF;

  -- Update shared order status
  UPDATE shared_orders
  SET status = 'completed'
  WHERE share_id = p_share_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'total', v_total
  );
END;
$$;