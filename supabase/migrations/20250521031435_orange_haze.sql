/*
  # Fix ambiguous referrer_id column reference

  1. Changes
    - Update process_shared_order_payment function to explicitly specify table for referrer_id column
    - Add explicit table references for all ambiguous column references
    - Add gateway_id parameter to function
*/

CREATE OR REPLACE FUNCTION process_shared_order_payment(
  p_share_id TEXT,
  p_payment_method TEXT,
  p_gateway_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id UUID;
  v_user_id UUID;
  v_referrer_id UUID;
  v_result jsonb;
BEGIN
  -- Get order details from shared_orders
  SELECT order_id INTO v_order_id
  FROM shared_orders
  WHERE share_id = p_share_id AND status = 'pending';

  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired share ID'
    );
  END IF;

  -- Get user_id and referrer_id from the order
  SELECT 
    orders.user_id,
    user_profiles.referrer_id INTO v_user_id, v_referrer_id
  FROM orders
  JOIN user_profiles ON user_profiles.id = orders.user_id
  WHERE orders.id = v_order_id;

  -- Update order with payment information
  UPDATE orders
  SET 
    payment_method = p_payment_method,
    payment_status = 'processing',
    status = 'processing',
    updated_at = NOW()
  WHERE id = v_order_id;

  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = NOW()
  WHERE share_id = p_share_id;

  -- Create success response
  v_result := jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'user_id', v_user_id,
    'referrer_id', v_referrer_id
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;