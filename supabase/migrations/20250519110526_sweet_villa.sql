/*
  # Update share_order function
  
  1. Changes
    - Drop existing share_order function
    - Recreate with new return type (jsonb)
    - Add security checks and improved error handling
*/

-- First drop the existing function
DROP FUNCTION IF EXISTS public.share_order(uuid, integer);

-- Recreate the function with new return type
CREATE FUNCTION public.share_order(
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
BEGIN
  -- Get the user_id from the order to verify ownership
  SELECT user_id INTO v_user_id
  FROM orders
  WHERE id = p_order_id;

  -- Verify the order belongs to the current user
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to share this order';
  END IF;

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
    now() + (p_expiry_hours || ' hours')::interval
  )
  RETURNING id INTO v_shared_order_id;

  -- Return the share details
  RETURN jsonb_build_object(
    'share_id', v_share_id,
    'expires_at', now() + (p_expiry_hours || ' hours')::interval
  );
END;
$$;