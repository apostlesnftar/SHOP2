/*
  # Add share_order function for shared orders

  1. New Function
    - `share_order(p_order_id uuid)`
      - Creates a shared order record for a given order
      - Returns success status and share_id or error message
      - Validates order ownership and existing shares
      - Sets expiration to 24 hours from creation

  2. Security
    - Function is accessible to authenticated users only
    - Users can only share their own orders
    - Validates order exists and belongs to user
*/

-- Create the share_order function
CREATE OR REPLACE FUNCTION public.share_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_share_id text;
  v_expires_at timestamptz;
  v_order_exists boolean;
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User must be authenticated'
    );
  END IF;

  -- Check if order exists and belongs to user
  SELECT EXISTS (
    SELECT 1 
    FROM orders 
    WHERE id = p_order_id 
    AND user_id = v_user_id
  ) INTO v_order_exists;

  IF NOT v_order_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found or does not belong to user'
    );
  END IF;

  -- Check if order already has a share
  IF EXISTS (
    SELECT 1 
    FROM shared_orders 
    WHERE order_id = p_order_id
    AND status = 'pending'
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order is already shared'
    );
  END IF;

  -- Generate a unique share ID (using a simple UUID for demo)
  v_share_id := replace(gen_random_uuid()::text, '-', '');
  
  -- Set expiration to 24 hours from now
  v_expires_at := now() + interval '24 hours';

  -- Create the shared order record
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    v_expires_at
  );

  -- Return success response with share ID
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_share_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.share_order(uuid) TO authenticated;