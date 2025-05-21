/*
  # Add share_order function
  
  1. New Functions
    - `share_order`: Creates a shared order record and returns success/error status
      - Input: p_order_id (uuid) - The ID of the order to share
      - Output: JSON object with success status and share_id/error message
  
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
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Check if order exists and belongs to the user
  SELECT EXISTS (
    SELECT 1 
    FROM orders 
    WHERE id = p_order_id 
    AND user_id = v_user_id
  ) INTO v_order_exists;
  
  IF NOT v_order_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found or access denied'
    );
  END IF;
  
  -- Generate a unique share ID (using a simple UUID to text conversion)
  v_share_id := replace(gen_random_uuid()::text, '-', '');
  
  -- Create the shared order record
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    now() + interval '24 hours'
  );
  
  -- Return success response with share ID
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_share_id
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.share_order(uuid) TO authenticated;