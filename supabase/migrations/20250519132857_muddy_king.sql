/*
  # Fix share_order function
  
  1. Changes
    - Drop all existing share_order functions
    - Create new share_order function with proper parameter handling
    - Add validation for friend payment orders
    - Return consistent response format
*/

-- Drop all existing share_order functions
DROP FUNCTION IF EXISTS public.share_order(uuid);
DROP FUNCTION IF EXISTS public.share_order(uuid, integer);
DROP FUNCTION IF EXISTS public.share_order(jsonb);

-- Create new share_order function
CREATE OR REPLACE FUNCTION public.share_order(p_params jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_share_id text;
  v_expires_at timestamptz;
  v_order_status text;
  v_payment_method text;
  v_order_id uuid;
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Extract order_id from params
  v_order_id := (p_params->>'order_id')::uuid;
  
  -- Validate order_id
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'order_id is required'
    );
  END IF;

  -- Get order details
  SELECT 
    status,
    payment_method 
  INTO v_order_status, v_payment_method
  FROM orders
  WHERE id = v_order_id
  AND user_id = v_user_id;

  -- Verify the order exists and belongs to user
  IF v_order_status IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found or access denied'
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
    v_order_id,
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
    'order_id', v_order_id
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.share_order(jsonb) TO authenticated;