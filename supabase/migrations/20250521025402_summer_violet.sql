/*
  # Fix ambiguous referrer_id column reference

  1. Changes
    - Update process_friend_payment function to explicitly specify table for referrer_id column
    - Add proper table alias to avoid ambiguity in joins
*/

CREATE OR REPLACE FUNCTION public.process_friend_payment(p_share_id text, p_payment_method text)
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
    SET payment_status = 'completed',
        payment_method = p_payment_method,
        status = 'processing'
    WHERE id = v_order_id;

    -- Process referral commission if applicable
    WITH referral_chain AS (
      SELECT 
        up.id as user_id,
        up2.id as referrer_id,
        1 as level
      FROM user_profiles up
      LEFT JOIN user_profiles up2 ON up2.id = up.referrer_id
      WHERE up.id = v_user_id
      
      UNION ALL
      
      SELECT 
        rc.referrer_id,
        up.referrer_id,
        rc.level + 1
      FROM referral_chain rc
      JOIN user_profiles up ON up.id = rc.referrer_id
      WHERE up.referrer_id IS NOT NULL
        AND rc.level < 3
    )
    INSERT INTO commissions (agent_id, order_id, amount, status)
    SELECT 
      a.user_id,
      v_order_id,
      ROUND(v_total * (a.commission_rate / 100), 2),
      'pending'
    FROM referral_chain rc
    JOIN agents a ON a.user_id = rc.referrer_id
    WHERE a.status = 'active';

    -- Return success
    v_result := jsonb_build_object(
      'success', true,
      'order_id', v_order_id
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback will happen automatically
      v_result := jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;

  RETURN v_result;
END;
$$;