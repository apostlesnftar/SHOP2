/*
  # Fix ambiguous referrer_id reference

  1. Changes
    - Update process_friend_payment function to explicitly qualify referrer_id column
    - Add better error handling and validation
    - Improve transaction management
*/

CREATE OR REPLACE FUNCTION process_friend_payment(p_share_id text, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_total numeric(10,2);
  v_referrer_id uuid;
  v_result jsonb;
BEGIN
  -- Get order details from shared_orders
  SELECT o.id, o.user_id, o.total
  INTO v_order_id, v_user_id, v_total
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
  AND so.status = 'pending'
  AND so.expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;

  -- Get referrer_id from user_profiles
  SELECT up.referrer_id
  INTO v_referrer_id
  FROM user_profiles up
  WHERE up.id = v_user_id;

  -- Begin transaction
  BEGIN
    -- Update order status
    UPDATE orders
    SET 
      status = 'processing',
      payment_status = 'completed',
      payment_method = p_payment_method
    WHERE id = v_order_id
    AND status = 'pending';

    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE share_id = p_share_id
    AND status = 'pending';

    -- Process commission if there's a referrer
    IF v_referrer_id IS NOT NULL THEN
      -- Process commission logic here
      -- This is handled by the order status change trigger
      NULL;
    END IF;

    v_result = jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'message', 'Payment processed successfully'
    );

    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      -- Roll back transaction on error
      RAISE NOTICE 'Error processing payment: %', SQLERRM;
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;