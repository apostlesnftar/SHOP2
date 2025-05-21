/*
  # Fix ambiguous referrer_id reference

  1. Changes
    - Update process_friend_payment function to use explicit table references for referrer_id
    - Add explicit table aliases to avoid column ambiguity
*/

CREATE OR REPLACE FUNCTION public.process_friend_payment(p_share_id text, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order shared_orders;
  v_order orders;
  v_result jsonb;
BEGIN
  -- Get shared order
  SELECT * INTO v_shared_order
  FROM shared_orders so
  WHERE so.share_id = p_share_id
  AND so.status = 'pending'
  AND so.expires_at > now();

  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;

  -- Get order
  SELECT * INTO v_order
  FROM orders o
  WHERE o.id = v_shared_order.order_id
  AND o.status = 'pending'
  AND o.payment_status = 'pending';

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found or already processed'
    );
  END IF;

  -- Update order with payment method
  UPDATE orders
  SET payment_method = p_payment_method,
      updated_at = now()
  WHERE id = v_order.id;

  -- Update shared order status
  UPDATE shared_orders
  SET status = 'completed',
      updated_at = now()
  WHERE id = v_shared_order.id;

  -- If there's a referrer, create user profile relationship
  IF v_shared_order.referrer_id IS NOT NULL THEN
    UPDATE user_profiles up
    SET referrer_id = v_shared_order.referrer_id
    WHERE up.id = v_order.user_id
    AND up.referrer_id IS NULL;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id
  );
END;
$$;