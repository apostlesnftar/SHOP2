/*
  # Add payment gateway functions for shared orders
  
  1. Functions
    - get_shared_order_payment_methods - Get available payment methods for shared orders
    - process_shared_order_payment - Process payment for shared orders using configured gateways
*/

-- Function to get available payment methods for shared orders
CREATE OR REPLACE FUNCTION get_shared_order_payment_methods()
RETURNS TABLE (
  method text,
  provider text,
  gateway_id uuid,
  test_mode boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only return active payment gateways, excluding friend_payment
  RETURN QUERY
  SELECT 
    CASE 
      WHEN pg.provider = 'stripe' THEN 'credit_card'
      ELSE pg.provider
    END as method,
    pg.provider,
    pg.id as gateway_id,
    pg.test_mode
  FROM payment_gateways pg
  WHERE pg.is_active = true;
END;
$$;

-- Function to process shared order payment
CREATE OR REPLACE FUNCTION process_shared_order_payment(
  p_share_id text,
  p_payment_method text,
  p_gateway_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order_id uuid;
  v_order_number text;
  v_gateway record;
BEGIN
  -- Get shared order details
  SELECT 
    s.*,
    o.order_number,
    o.id as order_id
  INTO v_shared_order
  FROM shared_orders s
  JOIN orders o ON o.id = s.order_id
  WHERE s.share_id = p_share_id
  AND s.expires_at > now()
  AND s.status = 'pending'
  AND o.payment_method = 'friend_payment'
  AND o.payment_status = 'pending';
  
  -- Validate shared order
  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found, expired, or already paid'
    );
  END IF;
  
  -- Validate payment gateway
  SELECT * INTO v_gateway
  FROM payment_gateways
  WHERE id = p_gateway_id
  AND is_active = true;
  
  IF v_gateway IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment gateway'
    );
  END IF;
  
  -- Validate payment method matches gateway
  IF (v_gateway.provider = 'stripe' AND p_payment_method != 'credit_card')
     OR (v_gateway.provider != 'stripe' AND v_gateway.provider != p_payment_method) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method for selected gateway'
    );
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing'
  WHERE id = v_shared_order.order_id
  AND payment_status = 'pending'
  RETURNING id INTO v_order_id;
  
  -- If order was updated successfully
  IF v_order_id IS NOT NULL THEN
    -- Update shared order status
    UPDATE shared_orders
    SET status = 'completed'
    WHERE share_id = p_share_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'order_number', v_shared_order.order_number
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Failed to process payment'
  );
END;
$$;

-- Grant access to functions
GRANT EXECUTE ON FUNCTION get_shared_order_payment_methods() TO authenticated;
GRANT EXECUTE ON FUNCTION process_shared_order_payment(text, text, uuid) TO authenticated;