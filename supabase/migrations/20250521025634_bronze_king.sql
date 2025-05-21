/*
  # Fix ambiguous referrer_id reference

  1. Changes
    - Update the process_friend_payment function to properly qualify the referrer_id column
    - Ensure all references to referrer_id explicitly specify the user_profiles table

  2. Notes
    - This fixes the "column reference 'referrer_id' is ambiguous" error in the payment processing
    - No schema changes are made, only function updates
*/

CREATE OR REPLACE FUNCTION process_friend_payment(p_share_id text, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order shared_orders;
  v_order orders;
  v_user_id uuid;
  v_referrer_id uuid;
BEGIN
  -- Get the shared order and related order
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Shared order not found or already processed');
  END IF;

  -- Check if the order exists and is in a valid state
  SELECT * INTO v_order
  FROM orders
  WHERE id = v_shared_order.order_id
  FOR UPDATE;

  IF NOT FOUND OR v_order.status != 'pending' OR v_order.payment_status != 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid order state');
  END IF;

  -- Get the referrer_id from user_profiles for the order's user
  SELECT user_profiles.referrer_id INTO v_referrer_id
  FROM user_profiles
  WHERE user_profiles.id = v_order.user_id;

  -- Update order status
  UPDATE orders
  SET 
    payment_method = p_payment_method,
    status = 'processing',
    payment_status = 'processing',
    updated_at = now()
  WHERE id = v_order.id;

  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = now()
  WHERE id = v_shared_order.id;

  -- Process agent commission if applicable
  IF v_referrer_id IS NOT NULL THEN
    PERFORM process_agent_commission(v_order.id);
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;