-- Create a minimal version of the process_friend_payment function
CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_order_number text;
BEGIN
  -- Get shared order details
  SELECT 
    so.order_id,
    o.order_number,
    o.user_id
  INTO 
    v_order_id,
    v_order_number,
    v_user_id
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
  AND so.status = 'pending';
  
  -- Validate shared order
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or already processed'
    );
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing',
    payment_method = p_payment_method
  WHERE id = v_order_id;
  
  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed'
  WHERE share_id = p_share_id;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_number', v_order_number
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO anon;

-- Add policies for anonymous users to access shared orders
CREATE POLICY "Allow anon select on shared_orders" 
ON shared_orders 
FOR SELECT 
TO anon 
USING (true);

CREATE POLICY "Allow anon update on shared_orders" 
ON shared_orders 
FOR UPDATE 
TO anon 
USING (true);

CREATE POLICY "Allow anon select on orders" 
ON orders 
FOR SELECT 
TO anon 
USING (true);

CREATE POLICY "Allow anon update on orders" 
ON orders 
FOR UPDATE 
TO anon 
USING (true);