/*
  # Fix Shared Order Functionality
  
  1. Changes
    - Add function to get shared order details
    - Add function to validate shared order
    - Add function to process shared order payment
    - Add indexes for better performance
  
  2. Security
    - Add RLS policies for shared orders
    - Ensure proper validation of shared orders
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.share_order(uuid, integer);
DROP FUNCTION IF EXISTS public.get_shared_order(text);

-- Create function to get shared order details
CREATE OR REPLACE FUNCTION public.get_shared_order(p_share_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order record;
  v_order_items jsonb;
BEGIN
  -- Get shared order details
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id
  AND expires_at > now()
  AND status = 'pending';
  
  -- Check if shared order exists and is valid
  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'Shared order not found or expired'
    );
  END IF;
  
  -- Get order details
  SELECT 
    o.*,
    json_agg(
      jsonb_build_object(
        'id', oi.id,
        'product_id', oi.product_id,
        'quantity', oi.quantity,
        'price', oi.price,
        'product', jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'images', p.images
        )
      )
    ) as items
  INTO v_order
  FROM orders o
  LEFT JOIN order_items oi ON oi.order_id = o.id
  LEFT JOIN products p ON p.id = oi.product_id
  WHERE o.id = v_shared_order.order_id
  GROUP BY o.id;
  
  -- Return full order details
  RETURN jsonb_build_object(
    'share_id', v_shared_order.share_id,
    'expires_at', v_shared_order.expires_at,
    'status', v_shared_order.status,
    'order', jsonb_build_object(
      'id', v_order.id,
      'order_number', v_order.order_number,
      'status', v_order.status,
      'payment_status', v_order.payment_status,
      'subtotal', v_order.subtotal,
      'tax', v_order.tax,
      'shipping', v_order.shipping,
      'total', v_order.total,
      'items', v_order.items
    )
  );
END;
$$;

-- Create function to share order
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
  v_order_status text;
  v_payment_method text;
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
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Verify the order belongs to the current user
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to share this order';
  END IF;
  
  -- Verify the order is using friend payment
  IF v_payment_method != 'friend_payment' THEN
    RAISE EXCEPTION 'Only friend payment orders can be shared';
  END IF;
  
  -- Verify the order is in a shareable state
  IF v_order_status NOT IN ('pending', 'processing') THEN
    RAISE EXCEPTION 'Order cannot be shared in its current state';
  END IF;

  -- Calculate expiry timestamp
  v_expires_at := now() + (p_expiry_hours || ' hours')::interval;

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
    'share_id', v_share_id,
    'expires_at', v_expires_at,
    'order_id', p_order_id
  );
END;
$$;

-- Add unique constraint on order_id for shared_orders
ALTER TABLE shared_orders
ADD CONSTRAINT shared_orders_order_id_key UNIQUE (order_id);

-- Add index for share_id lookups
CREATE INDEX IF NOT EXISTS idx_shared_orders_share_id 
ON shared_orders(share_id);

-- Add index for expiry checks
CREATE INDEX IF NOT EXISTS idx_shared_orders_expires_at 
ON shared_orders(expires_at);

-- Update shared orders RLS policies
DROP POLICY IF EXISTS "Anyone can view valid shared orders" ON shared_orders;
CREATE POLICY "Anyone can view valid shared orders" ON shared_orders
  FOR SELECT USING (
    expires_at > now() 
    AND status = 'pending'
  );

-- Function to process shared order payment
CREATE OR REPLACE FUNCTION process_shared_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order_id uuid;
BEGIN
  -- Get shared order
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id
  AND expires_at > now()
  AND status = 'pending';
  
  -- Validate shared order
  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing'
  WHERE id = v_shared_order.order_id
  RETURNING id INTO v_order_id;
  
  -- Update shared order status
  UPDATE shared_orders
  SET status = 'completed'
  WHERE share_id = p_share_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id
  );
END;
$$;