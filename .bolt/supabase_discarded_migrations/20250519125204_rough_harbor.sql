/*
  # Fix share order function
  
  1. Changes
    - Simplify share_order function to use a single parameter
    - Add proper error handling and validation
    - Return consistent response format
*/

-- Drop existing function
DROP FUNCTION IF EXISTS public.share_order(uuid, integer);
DROP FUNCTION IF EXISTS public.share_order(p_order_id uuid, p_expiry_hours integer);
DROP FUNCTION IF EXISTS public.share_order(p_params jsonb);

-- Create new version with single parameter
CREATE OR REPLACE FUNCTION public.share_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_share_id text;
  v_user_id uuid;
  v_order_status text;
  v_payment_method text;
  v_expires_at timestamptz;
BEGIN
  -- Get order details
  SELECT 
    user_id, 
    status,
    payment_method 
  INTO v_user_id, v_order_status, v_payment_method
  FROM orders
  WHERE id = p_order_id;

  -- Verify the order exists
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Verify the order belongs to the current user
  IF v_user_id != auth.uid() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Not authorized to share this order'
    );
  END IF;
  
  -- Verify the order is using friend payment
  IF v_payment_method != 'friend_payment' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Only friend payment orders can be shared'
    );
  END IF;
  
  -- Verify the order is in a shareable state
  IF v_order_status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order cannot be shared in its current state'
    );
  END IF;

  -- Calculate expiry timestamp (24 hours)
  v_expires_at := now() + interval '24 hours';

  -- Generate a unique share ID
  v_share_id := encode(gen_random_bytes(6), 'hex');

  -- Create or update the shared order record
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    v_expires_at
  )
  ON CONFLICT (order_id) 
  DO UPDATE SET
    share_id = v_share_id,
    expires_at = v_expires_at,
    status = 'pending';

  -- Return the share details
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_share_id,
    'expires_at', v_expires_at,
    'order_id', p_order_id
  );
END;
$$;