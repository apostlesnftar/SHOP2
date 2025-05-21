/*
  # Enhance Friend Payment and Shared Orders
  
  1. New Functions
    - get_shared_order_details - Get full order details including shipping address (partially masked)
    - process_friend_payment - Process payment for shared orders
    
  2. Security
    - Add additional validation for shared orders
    - Ensure sensitive data is properly masked
*/

-- Function to get shared order details with masked shipping address
CREATE OR REPLACE FUNCTION get_shared_order_details(p_share_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order record;
  v_address record;
  v_masked_address jsonb;
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
  
  -- Get order details with address
  SELECT 
    o.*,
    a.city,
    a.state,
    a.country,
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
  LEFT JOIN addresses a ON a.id = o.shipping_address_id
  WHERE o.id = v_shared_order.order_id
  GROUP BY o.id, a.city, a.state, a.country;
  
  -- Create masked address object
  v_masked_address := jsonb_build_object(
    'city', v_order.city,
    'state', v_order.state,
    'country', v_order.country
  );
  
  -- Return full order details with masked address
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
      'items', v_order.items,
      'shipping_address', v_masked_address
    )
  );
END;
$$;

-- Function to process friend payment
CREATE OR REPLACE FUNCTION process_friend_payment(
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
  v_order_number text;
BEGIN
  -- Get shared order
  SELECT 
    s.*,
    o.order_number
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
  
  -- Validate payment method
  IF p_payment_method NOT IN ('credit_card', 'paypal') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method'
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