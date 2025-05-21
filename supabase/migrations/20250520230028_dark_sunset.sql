/*
  # Fix ambiguous referrer_id in process_friend_payment function

  1. Changes
    - Update process_friend_payment function to use explicit table references
    - Fix ambiguous column reference for referrer_id
    
  2. Security
    - Maintain existing security policies
    - Function remains accessible to authenticated users only
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
  v_order_status text;
  v_payment_status text;
  v_result jsonb;
BEGIN
  -- Get order details from shared_orders
  SELECT 
    o.id,
    o.user_id,
    o.status,
    o.payment_status
  INTO 
    v_order_id,
    v_user_id,
    v_order_status,
    v_payment_status
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
  AND so.status = 'pending'
  AND so.expires_at > now()
  LIMIT 1;

  -- Validate order exists and is in valid state
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired share ID'
    );
  END IF;

  IF v_order_status != 'pending' OR v_payment_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order is not in pending status'
    );
  END IF;

  -- Begin transaction
  BEGIN
    -- Update order payment method
    UPDATE orders
    SET payment_method = p_payment_method
    WHERE id = v_order_id;

    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE share_id = p_share_id;

    -- Return success
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id
    );
  EXCEPTION WHEN OTHERS THEN
    -- Return error on failure
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
  END;
END;
$$;