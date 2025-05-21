/*
  # Fix ambiguous referrer_id reference in process_friend_payment function

  1. Changes
    - Update process_friend_payment function to explicitly reference shared_orders.referrer_id
    - Fix ambiguous column reference in the function's SQL query
    - Maintain existing functionality while ensuring correct referrer tracking

  2. Security
    - No changes to RLS policies
    - Maintains existing security constraints
*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS process_friend_payment(p_share_id text, p_payment_method text);

-- Recreate the function with fixed column references
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
  v_referrer_id uuid;
  v_order_status text;
  v_payment_status text;
  v_result jsonb;
BEGIN
  -- Get order details from shared_orders, explicitly referencing the referrer_id
  SELECT 
    so.order_id,
    o.user_id,
    so.referrer_id,
    o.status,
    o.payment_status
  INTO 
    v_order_id,
    v_user_id,
    v_referrer_id,
    v_order_status,
    v_payment_status
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
  AND so.status = 'pending'
  AND so.expires_at > now();

  -- Validate order exists and is in correct state
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

  -- Begin transaction
  BEGIN
    -- Update order status and payment method
    UPDATE orders
    SET 
      payment_method = p_payment_method,
      status = 'processing',
      payment_status = 'processing',
      updated_at = now()
    WHERE id = v_order_id;

    -- Update shared order status
    UPDATE shared_orders
    SET 
      status = 'completed',
      updated_at = now()
    WHERE share_id = p_share_id;

    -- Return success response
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'referrer_id', v_referrer_id
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Return error response
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;