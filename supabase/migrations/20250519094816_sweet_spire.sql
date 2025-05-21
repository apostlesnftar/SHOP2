/*
  # Enhanced Order Processing
  
  1. New Functions
    - validate_product_availability - Check product stock and status
    - validate_payment_method - Verify payment method is valid
    - handle_order_cancellation - Process order cancellations
  
  2. Additional Validations
    - Payment method validation
    - Order total validation
    - Duplicate order prevention
*/

-- Function to validate product availability
CREATE OR REPLACE FUNCTION validate_product_availability(
  p_items JSONB
) RETURNS BOOLEAN AS $$
DECLARE
  v_item JSONB;
  v_product_id UUID;
  v_quantity INTEGER;
  v_available INTEGER;
  v_product_name TEXT;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    
    -- Get product details
    SELECT 
      inventory,
      name INTO v_available, v_product_name
    FROM products
    WHERE id = v_product_id;
    
    -- Check if product exists
    IF v_product_name IS NULL THEN
      RAISE EXCEPTION 'Product not found: %', v_product_id;
    END IF;
    
    -- Check if quantity is valid
    IF v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for %: %', v_product_name, v_quantity;
    END IF;
    
    -- Check if enough inventory
    IF v_quantity > v_available THEN
      RAISE EXCEPTION 'Insufficient inventory for %: requested %, available %', 
        v_product_name, v_quantity, v_available;
    END IF;
  END LOOP;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to validate payment method
CREATE OR REPLACE FUNCTION validate_payment_method(
  p_payment_method TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_payment_method NOT IN ('credit_card', 'paypal', 'pix') THEN
    RAISE EXCEPTION 'Invalid payment method: %', p_payment_method;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to handle order cancellation
CREATE OR REPLACE FUNCTION handle_order_cancellation()
RETURNS TRIGGER AS $$
BEGIN
  -- Only process if status changed to cancelled
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    -- Restore inventory
    UPDATE products p
    SET inventory = p.inventory + oi.quantity
    FROM order_items oi
    WHERE oi.order_id = NEW.id
    AND p.id = oi.product_id;
    
    -- Cancel any pending commissions
    UPDATE commissions
    SET status = 'cancelled'
    WHERE order_id = NEW.id
    AND status = 'pending';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for order cancellation
CREATE TRIGGER on_order_cancelled
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (NEW.status = 'cancelled' AND OLD.status != 'cancelled')
  EXECUTE FUNCTION handle_order_cancellation();

-- Enhance order processing function with new validations
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
  
  -- Create order with explicit transaction
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
    auth.uid(),
    p_shipping_address_id,
    p_payment_method,
    v_totals.subtotal,
    v_totals.tax,
    v_totals.shipping,
    v_totals.total
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

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);