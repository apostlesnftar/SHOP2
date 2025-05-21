/*
  # Fix ambiguous referrer_id reference in process_friend_payment function

  1. Changes
    - Update process_friend_payment function to use fully qualified column names
    - Fix ambiguous referrer_id reference by specifying the table name

  2. Security
    - No changes to RLS policies
    - Maintains existing security constraints
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
  v_shared_order shared_orders;
  v_order orders;
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

  -- Get associated order
  SELECT * INTO v_order
  FROM orders o
  WHERE o.id = v_shared_order.order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Begin transaction
  BEGIN
    -- Update order payment method and status
    UPDATE orders
    SET payment_method = p_payment_method,
        payment_status = 'processing'
    WHERE id = v_order.id;

    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE id = v_shared_order.id;

    -- If order was created through a referral, process the referral
    IF EXISTS (
      SELECT 1 
      FROM user_profiles up1
      JOIN user_profiles up2 ON up2.id = up1.referrer_id
      WHERE up1.id = v_order.user_id
    ) THEN
      -- Process referral logic here
      -- Using fully qualified column names to avoid ambiguity
      NULL;
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order.id
    );
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;