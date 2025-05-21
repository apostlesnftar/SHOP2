/*
  # Fix share_order function signature and return type
  
  1. Changes
    - Drop existing function
    - Recreate with correct parameter order and return type
    - Add proper error handling and validation
    - Return consistent JSON response
*/

-- First drop the existing function
DROP FUNCTION IF EXISTS public.share_order(uuid, integer);

-- Recreate the function with proper signature and return type
CREATE OR REPLACE FUNCTION public.share_order(
  p_order_id uuid,
  p_expiry_hours integer DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_share_id text;
  v_user_id uuid;
  v_shared_order_id uuid;
  v_expires_at timestamptz;
BEGIN
  -- Get the user_id from the order to verify ownership
  SELECT user_id INTO v_user_id
  FROM orders
  WHERE id = p_order_id;

  -- Verify the order exists
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Verify the order belongs to the current user
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to share this order';
  END IF;

  -- Calculate expiry timestamp
  v_expires_at := now() + (p_expiry_hours || ' hours')::interval;

  -- Generate a unique share ID (using a combination of random strings)
  v_share_id := encode(gen_random_bytes(12), 'hex');

  -- Create the shared order record
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    v_expires_at
  )
  RETURNING id INTO v_shared_order_id;

  -- Return the share details
  RETURN jsonb_build_object(
    'share_id', v_share_id,
    'expires_at', v_expires_at,
    'order_id', p_order_id
  );
END;
$$;