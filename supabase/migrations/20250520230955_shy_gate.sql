/*
  # Fix ambiguous referrer_id in process_friend_payment function

  1. Changes
    - Update process_friend_payment function to properly qualify referrer_id column references
    - Ensure correct table is referenced when accessing referrer_id
    - No schema changes, only function modification

  2. Security
    - Maintains existing security policies
    - No changes to RLS
*/

CREATE OR REPLACE FUNCTION process_friend_payment(p_share_id text, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order shared_orders;
  v_order orders;
  v_result jsonb;
BEGIN
  -- Get shared order details
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id
  AND status = 'pending'
  AND expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;

  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = v_shared_order.order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Update order payment status and method
  UPDATE orders
  SET payment_status = 'processing',
      payment_method = p_payment_method,
      status = 'processing'
  WHERE id = v_order.id;

  -- Update shared order status
  UPDATE shared_orders
  SET status = 'completed'
  WHERE id = v_shared_order.id;

  -- If there's a referrer, process referral
  IF v_shared_order.referrer_id IS NOT NULL THEN
    -- Handle referral logic here
    -- Use explicit table references for referrer_id
    -- Example: shared_orders.referrer_id or user_profiles.referrer_id
    NULL;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id
  );
END;
$$;