/*
  # Fix share_order function
  
  1. Changes
    - Drop existing share_order functions
    - Create new version with proper parameter handling
    - Add validation for friend payment orders
    - Return consistent response format
    - Fix RLS policies for shared orders
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS public.share_order(uuid);
DROP FUNCTION IF EXISTS public.share_order(uuid, integer);
DROP FUNCTION IF EXISTS public.share_order(jsonb);

-- Create new share_order function
CREATE OR REPLACE FUNCTION public.share_order(p_order_id uuid)
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
  v_shared_order_id uuid;
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Get order details
  SELECT 
    status,
    payment_method 
  INTO v_order_status, v_payment_method
  FROM orders
  WHERE id = p_order_id
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
    p_order_id,
    v_expires_at
  )
  ON CONFLICT (order_id) 
  DO UPDATE SET
    share_id = v_share_id,
    expires_at = v_expires_at,
    status = 'pending'
  RETURNING id INTO v_shared_order_id;

  -- Return the share details
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_share_id,
    'expires_at', v_expires_at,
    'order_id', p_order_id
  );
END;
$$;

-- Update RLS policies for shared orders
DROP POLICY IF EXISTS "Anyone can view valid shared orders" ON shared_orders;
DROP POLICY IF EXISTS "Users can create shared orders for their own orders" ON shared_orders;

CREATE POLICY "Anyone can view valid shared orders" ON shared_orders
  FOR SELECT USING (
    expires_at > now() 
    AND status = 'pending'
  );

CREATE POLICY "Users can create shared orders for their own orders" ON shared_orders
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shared_orders.order_id
      AND orders.user_id = auth.uid()
      AND orders.payment_method = 'friend_payment'
    )
  );

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.share_order(uuid) TO authenticated;