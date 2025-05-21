/*
  # Add share_order function for friend payment feature

  1. New Function
    - `share_order(order_id uuid)`: Creates a shared order record for friend payment
      - Generates a unique share_id
      - Sets expiration to 24 hours from creation
      - Returns share_id and success status

  2. Security
    - Function is accessible to authenticated users only
    - Users can only share their own orders
*/

-- Create the share_order function
CREATE OR REPLACE FUNCTION public.share_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_share_id text;
  v_user_id uuid;
  v_order_exists boolean;
  v_shared_order_id uuid;
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Check if the order exists and belongs to the current user
  SELECT EXISTS (
    SELECT 1 
    FROM orders 
    WHERE id = p_order_id 
    AND user_id = v_user_id
  ) INTO v_order_exists;
  
  -- If order doesn't exist or doesn't belong to user, return error
  IF NOT v_order_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found or access denied'
    );
  END IF;
  
  -- Generate a unique share_id (using a simple pattern for demo)
  v_share_id := encode(gen_random_bytes(12), 'hex');
  
  -- Create the shared order record
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    now() + interval '24 hours'
  )
  RETURNING id INTO v_shared_order_id;
  
  -- Return success response with share_id
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_share_id,
    'shared_order_id', v_shared_order_id
  );
  
EXCEPTION WHEN OTHERS THEN
  -- Return error response
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.share_order(uuid) TO authenticated;