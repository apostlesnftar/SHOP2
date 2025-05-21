/*
  # Create share_order function

  1. New Functions
    - `share_order`: Creates a shared order entry and returns the share details
      - Input:
        - p_order_id: UUID of the order to share
        - p_expiry_hours: Number of hours until the share expires
      - Output:
        - share_id: Generated share ID
        - order_id: Original order ID

  2. Security
    - Function is accessible to authenticated users only
    - Validates that the user owns the order being shared
*/

CREATE OR REPLACE FUNCTION public.share_order(
  p_order_id uuid,
  p_expiry_hours integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_share_id text;
  v_result json;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Verify the order belongs to the current user
  IF NOT EXISTS (
    SELECT 1 FROM orders 
    WHERE id = p_order_id 
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Order not found or unauthorized';
  END IF;

  -- Generate a unique share ID
  v_share_id := encode(gen_random_bytes(12), 'hex');

  -- Create the shared order entry
  INSERT INTO shared_orders (
    share_id,
    order_id,
    status,
    expires_at
  ) VALUES (
    v_share_id,
    p_order_id,
    'pending',
    NOW() + (p_expiry_hours || ' hours')::interval
  );

  -- Prepare the result
  v_result := json_build_object(
    'share_id', v_share_id,
    'order_id', p_order_id
  );

  RETURN v_result;
END;
$$;