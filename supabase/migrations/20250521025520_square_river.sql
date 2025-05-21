/*
  # Fix ambiguous referrer_id column reference

  1. Changes
    - Update process_friend_payment function to explicitly specify table for referrer_id column
    - Add proper table aliases to avoid ambiguity in joins
    - Improve error handling and validation

  2. Security
    - No changes to security policies
    - Maintains existing access controls
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
    o.id,
    o.user_id,
    o.total
  INTO 
    v_order_id,
    v_user_id,
    v_total
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
    AND so.status = 'pending'
    AND so.expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired shared order'
    );
  END IF;

  -- Begin transaction
  BEGIN
    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE share_id = p_share_id;

    -- Update order payment status and method
    UPDATE orders
    SET 
      payment_status = 'completed',
      payment_method = p_payment_method,
      status = 'processing'
    WHERE id = v_order_id;

    -- If there's a referrer, process commission
    WITH referrer_data AS (
      SELECT 
        up.referrer_id,
        a.commission_rate
      FROM user_profiles up
      LEFT JOIN agents a ON a.user_id = up.referrer_id
      WHERE up.id = v_user_id
        AND up.referrer_id IS NOT NULL
        AND EXISTS (
          SELECT 1 
          FROM agents 
          WHERE user_id = up.referrer_id 
          AND status = 'active'
        )
    )
    INSERT INTO commissions (
      agent_id,
      order_id,
      amount,
      status
    )
    SELECT 
      rd.referrer_id,
      v_order_id,
      (v_total * rd.commission_rate / 100),
      'pending'
    FROM referrer_data rd
    WHERE rd.referrer_id IS NOT NULL;

    -- Return success
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id
    );

  EXCEPTION WHEN OTHERS THEN
    -- Return error details
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
  END;
END;
$$;