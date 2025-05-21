/*
  # Fix ambiguous referrer_id column reference

  1. Changes
    - Update process_friend_payment function to explicitly specify table for referrer_id
    - Add proper error handling for missing share_id
    - Add proper validation for payment method
*/

CREATE OR REPLACE FUNCTION process_friend_payment(p_share_id text, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_order_status text;
  v_payment_status text;
  v_user_id uuid;
  v_referrer_id uuid;
BEGIN
  -- Get order details from shared_orders
  SELECT 
    so.order_id,
    o.status,
    o.payment_status,
    o.user_id,
    up.referrer_id
  INTO 
    v_order_id,
    v_order_status,
    v_payment_status,
    v_user_id,
    v_referrer_id
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  JOIN user_profiles up ON up.id = o.user_id
  WHERE so.share_id = p_share_id
  AND so.status = 'pending'
  AND so.expires_at > now();

  -- Validate order exists and is in valid state
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;

  IF v_order_status != 'pending' OR v_payment_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order is not in pending state'
    );
  END IF;

  -- Validate payment method
  IF NOT EXISTS (
    SELECT 1 FROM payment_gateways 
    WHERE code = p_payment_method 
    AND is_active = true
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method'
    );
  END IF;

  -- Update order status
  UPDATE orders
  SET 
    status = 'processing',
    payment_status = 'completed',
    payment_method = p_payment_method,
    updated_at = now()
  WHERE id = v_order_id;

  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = now()
  WHERE share_id = p_share_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id
  );
END;
$$;