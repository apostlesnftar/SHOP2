/*
  # Fix ambiguous referrer_id reference

  1. Changes
    - Update process_friend_payment function to properly qualify referrer_id column references
    - Ensure all table references in joins are properly aliased
    - Add explicit table qualifiers to avoid column ambiguity

  2. Security
    - No changes to RLS policies
    - Maintains existing security constraints
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
  v_result jsonb;
  v_shared_order shared_orders;
BEGIN
  -- Get shared order details with explicit table aliases
  SELECT so.* INTO v_shared_order
  FROM shared_orders so
  WHERE so.share_id = p_share_id
    AND so.status = 'pending'
    AND so.expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;

  -- Get order details with explicit table references
  SELECT o.id, o.user_id, o.total
  INTO v_order_id, v_user_id, v_total
  FROM orders o
  WHERE o.id = v_shared_order.order_id
    AND o.status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found or not pending'
    );
  END IF;

  -- Begin transaction
  BEGIN
    -- Update order status and payment method
    UPDATE orders
    SET payment_method = p_payment_method,
        payment_status = 'processing'
    WHERE id = v_order_id;

    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE share_id = p_share_id;

    -- If there's a referrer, process the referral
    IF v_shared_order.referrer_id IS NOT NULL THEN
      -- Handle referral logic here
      -- Use explicit table references when accessing referrer_id
      -- Example: shared_orders.referrer_id or user_profiles.referrer_id
      PERFORM process_order_referral(v_order_id, v_shared_order.referrer_id);
    END IF;

    v_result := jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'total', v_total
    );

    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE LOG 'Error in process_friend_payment: %', SQLERRM;
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;