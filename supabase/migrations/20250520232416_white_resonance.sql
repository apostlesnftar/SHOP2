/*
  # Fix ambiguous referrer_id reference in process_friend_payment function

  1. Changes
    - Update process_friend_payment function to explicitly reference shared_orders.referrer_id
    - Ensure correct handling of referrer_id for shared order payments
  
  2. Security
    - Maintains existing security policies
    - No changes to table permissions
*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS public.process_friend_payment(p_share_id text, p_payment_method text);

-- Recreate the function with explicit table references
CREATE OR REPLACE FUNCTION public.process_friend_payment(
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
  -- Get the shared order
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id
  AND status = 'pending'
  AND expires_at > now();

  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;

  -- Get the original order
  SELECT * INTO v_order
  FROM orders
  WHERE id = v_shared_order.order_id;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Original order not found'
    );
  END IF;

  -- Begin transaction
  BEGIN
    -- Update the shared order status
    UPDATE shared_orders
    SET status = 'completed',
        updated_at = now()
    WHERE id = v_shared_order.id;

    -- Update the order payment status and method
    UPDATE orders
    SET payment_status = 'completed',
        payment_method = p_payment_method,
        status = 'processing',
        updated_at = now()
    WHERE id = v_order.id;

    -- If there's a referrer, process the referral
    IF v_shared_order.referrer_id IS NOT NULL THEN
      -- Add your referral processing logic here
      -- This ensures we're explicitly using shared_orders.referrer_id
      PERFORM process_referral(v_shared_order.referrer_id, v_order.id);
    END IF;

    v_result := jsonb_build_object(
      'success', true,
      'order_id', v_order.id,
      'shared_order_id', v_shared_order.id
    );

    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'Error in process_friend_payment: %', SQLERRM;
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;