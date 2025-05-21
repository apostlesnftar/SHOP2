/*
  # Update Payment Method Validation
  
  1. Changes
    - Add 'friend_payment' as a valid payment method
    - Update payment validation function
    - Add specific handling for friend payment orders
*/

-- Update payment method validation function
CREATE OR REPLACE FUNCTION validate_payment_method(
  p_payment_method TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_payment_method NOT IN ('credit_card', 'paypal', 'friend_payment') THEN
    RAISE EXCEPTION 'Invalid payment method: %', p_payment_method;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to handle friend payment orders
CREATE OR REPLACE FUNCTION handle_friend_payment_order()
RETURNS TRIGGER AS $$
BEGIN
  -- For friend payment orders, set initial status to pending
  IF NEW.payment_method = 'friend_payment' THEN
    NEW.payment_status := 'pending';
    NEW.status := 'pending';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for friend payment orders
CREATE TRIGGER on_friend_payment_order
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION handle_friend_payment_order();

-- Update create_order function to handle friend payments
CREATE OR REPLACE FUNCTION create_order(
  p_items JSONB,
  p_shipping_address_id UUID,
  p_payment_method TEXT
) RETURNS TABLE (
  order_id UUID,
  order_number TEXT,
  total DECIMAL
) AS $$
DECLARE
  v_order_id UUID;
  v_order_number TEXT;
  v_totals RECORD;
BEGIN
  -- Validate inputs
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;
  
  -- Validate shipping address
  IF NOT EXISTS (
    SELECT 1 FROM addresses 
    WHERE id = p_shipping_address_id 
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Invalid shipping address';
  END IF;
  
  -- Validate products and inventory
  PERFORM validate_product_availability(p_items);
  
  -- Validate payment method
  PERFORM validate_payment_method(p_payment_method);
  
  -- Calculate totals
  SELECT * INTO v_totals 
  FROM calculate_order_totals(p_items, p_shipping_address_id);
  
  -- Generate unique order number
  v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
  
  -- Create order
  INSERT INTO orders (
    order_number,
    user_id,
    shipping_address_id,
    payment_method,
    subtotal,
    tax,
    shipping,
    total,
    status,
    payment_status
  ) VALUES (
    v_order_number,
    auth.uid(),
    p_shipping_address_id,
    p_payment_method,
    v_totals.subtotal,
    v_totals.tax,
    v_totals.shipping,
    v_totals.total,
    CASE 
      WHEN p_payment_method = 'friend_payment' THEN 'pending'
      ELSE 'processing'
    END,
    CASE 
      WHEN p_payment_method = 'friend_payment' THEN 'pending'
      ELSE 'completed'
    END
  ) RETURNING id INTO v_order_id;
  
  -- Create order items
  INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    price
  )
  SELECT
    v_order_id,
    (item->>'product_id')::UUID,
    (item->>'quantity')::INTEGER,
    get_effective_price((item->>'product_id')::UUID)
  FROM jsonb_array_elements(p_items) AS item;
  
  -- Return order details
  order_id := v_order_id;
  order_number := v_order_number;
  total := v_totals.total;
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;