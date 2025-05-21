/*
  # Fix ambiguous referrer_id reference

  1. Changes
    - Update process_friend_payment function to use fully qualified column names
    - Add explicit table references for referrer_id column
    - Improve error handling and validation
*/

CREATE OR REPLACE FUNCTION process_friend_payment(p_share_id text, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order shared_orders;
  v_order orders;
  v_user_profile user_profiles;
  v_result jsonb;
BEGIN
  -- Get shared order
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

  -- Get order
  SELECT * INTO v_order
  FROM orders
  WHERE id = v_shared_order.order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Get user profile
  SELECT * INTO v_user_profile
  FROM user_profiles
  WHERE id = v_order.user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User profile not found'
    );
  END IF;

  -- Update order
  UPDATE orders
  SET 
    payment_method = p_payment_method,
    payment_status = 'processing',
    status = 'processing',
    updated_at = now()
  WHERE id = v_order.id;

  -- Update shared order
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = now()
  WHERE id = v_shared_order.id;

  -- If there's a referrer, create commission for agent
  IF v_shared_order.referrer_id IS NOT NULL THEN
    -- Check if referrer is an agent
    IF EXISTS (
      SELECT 1 
      FROM agents 
      WHERE user_id = v_shared_order.referrer_id
      AND status = 'active'
    ) THEN
      -- Calculate commission (10% of order total)
      INSERT INTO commissions (
        agent_id,
        order_id,
        amount,
        status
      )
      VALUES (
        v_shared_order.referrer_id,
        v_order.id,
        v_order.total * 0.1,
        'pending'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'message', 'Payment processed successfully'
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;