/*
  # Stored Procedures
  
  1. Functions
    - process_order - Process a new order and update inventory
    - share_order - Generate a shared order link
*/

-- Process an order
CREATE OR REPLACE FUNCTION process_order(
  p_user_id UUID,
  p_shipping_address_id UUID,
  p_payment_method TEXT,
  p_subtotal DECIMAL,
  p_tax DECIMAL,
  p_shipping DECIMAL,
  p_total DECIMAL,
  p_items JSONB
) RETURNS UUID AS $$
DECLARE
  v_order_id UUID;
  v_order_number TEXT;
  v_item JSONB;
  v_product_id UUID;
  v_quantity INTEGER;
  v_price DECIMAL;
BEGIN
  -- Generate order number
  v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || FLOOR(RANDOM() * 10000)::TEXT;
  
  -- Create the order
  INSERT INTO orders (
    order_number, 
    user_id, 
    shipping_address_id, 
    payment_method, 
    subtotal, 
    tax, 
    shipping, 
    total
  ) VALUES (
    v_order_number,
    p_user_id,
    p_shipping_address_id,
    p_payment_method,
    p_subtotal,
    p_tax,
    p_shipping,
    p_total
  ) RETURNING id INTO v_order_id;
  
  -- Process each order item
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    v_price := (v_item->>'price')::DECIMAL;
    
    -- Insert order item
    INSERT INTO order_items (
      order_id, 
      product_id, 
      quantity, 
      price
    ) VALUES (
      v_order_id,
      v_product_id,
      v_quantity,
      v_price
    );
    
    -- Update product inventory
    UPDATE products
    SET inventory = inventory - v_quantity
    WHERE id = v_product_id;
  END LOOP;
  
  RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a shared order
CREATE OR REPLACE FUNCTION share_order(
  p_order_id UUID,
  p_expiry_hours INTEGER DEFAULT 24
) RETURNS TEXT AS $$
DECLARE
  v_share_id TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Generate a random share ID
  v_share_id := SUBSTR(MD5(p_order_id::TEXT || NOW()::TEXT), 1, 12);
  v_expires_at := NOW() + (p_expiry_hours || ' hours')::INTERVAL;
  
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
  
  RETURN v_share_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;