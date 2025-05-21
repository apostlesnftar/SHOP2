/*
  # Enhanced Order Processing
  
  1. Functions
    - validate_order - Validate order data before processing
    - calculate_order_totals - Calculate order totals including tax and shipping
    - update_inventory - Update product inventory after order
    - create_order_audit_log - Track order status changes
*/

-- Create order audit log table
CREATE TABLE IF NOT EXISTS order_audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id),
  user_id UUID NOT NULL,
  old_status TEXT,
  new_status TEXT NOT NULL,
  old_payment_status TEXT,
  new_payment_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE order_audit_logs ENABLE ROW LEVEL SECURITY;

-- Audit log policies
CREATE POLICY "Admins can view all audit logs" ON order_audit_logs
  FOR SELECT USING (is_admin());

CREATE POLICY "Users can view their own order audit logs" ON order_audit_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_audit_logs.order_id
      AND orders.user_id = auth.uid()
    )
  );

-- Function to validate order data
CREATE OR REPLACE FUNCTION validate_order(
  p_items JSONB,
  p_shipping_address_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_item JSONB;
  v_product_id UUID;
  v_quantity INTEGER;
  v_inventory INTEGER;
BEGIN
  -- Check if shipping address exists and belongs to user
  IF NOT EXISTS (
    SELECT 1 FROM addresses 
    WHERE id = p_shipping_address_id 
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Invalid shipping address';
  END IF;

  -- Validate each order item
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    
    -- Check if product exists and has sufficient inventory
    SELECT inventory INTO v_inventory
    FROM products
    WHERE id = v_product_id;
    
    IF v_inventory IS NULL THEN
      RAISE EXCEPTION 'Product not found: %', v_product_id;
    END IF;
    
    IF v_inventory < v_quantity THEN
      RAISE EXCEPTION 'Insufficient inventory for product: %', v_product_id;
    END IF;
  END LOOP;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate order totals
CREATE OR REPLACE FUNCTION calculate_order_totals(
  p_items JSONB,
  p_shipping_address_id UUID
) RETURNS TABLE (
  subtotal DECIMAL,
  tax DECIMAL,
  shipping DECIMAL,
  total DECIMAL
) AS $$
DECLARE
  v_item JSONB;
  v_product_id UUID;
  v_quantity INTEGER;
  v_price DECIMAL;
  v_discount INTEGER;
  v_item_total DECIMAL;
  v_subtotal DECIMAL := 0;
  v_tax_rate DECIMAL := 0.08; -- 8% tax rate
  v_shipping_threshold DECIMAL := 50;
  v_shipping_cost DECIMAL := 10;
BEGIN
  -- Calculate subtotal
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    
    SELECT 
      price,
      discount INTO v_price, v_discount
    FROM products
    WHERE id = v_product_id;
    
    -- Apply discount if available
    IF v_discount IS NOT NULL AND v_discount > 0 THEN
      v_price := v_price * (1 - v_discount::DECIMAL / 100);
    END IF;
    
    v_item_total := v_price * v_quantity;
    v_subtotal := v_subtotal + v_item_total;
  END LOOP;
  
  -- Calculate shipping (free if subtotal > threshold)
  shipping := CASE 
    WHEN v_subtotal >= v_shipping_threshold THEN 0 
    ELSE v_shipping_cost 
  END;
  
  -- Calculate tax
  tax := v_subtotal * v_tax_rate;
  
  -- Set return values
  subtotal := v_subtotal;
  total := v_subtotal + tax + shipping;
  
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to update inventory after order
CREATE OR REPLACE FUNCTION update_inventory()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update inventory when order is confirmed
  IF NEW.status = 'processing' AND OLD.status = 'pending' THEN
    UPDATE products p
    SET inventory = p.inventory - oi.quantity
    FROM order_items oi
    WHERE oi.order_id = NEW.id
    AND p.id = oi.product_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for inventory updates
CREATE TRIGGER update_inventory_on_order_confirmation
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (NEW.status = 'processing' AND OLD.status = 'pending')
  EXECUTE FUNCTION update_inventory();

-- Function to create order audit log
CREATE OR REPLACE FUNCTION create_order_audit_log()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO order_audit_logs (
    order_id,
    user_id,
    old_status,
    new_status,
    old_payment_status,
    new_payment_status,
    notes
  ) VALUES (
    NEW.id,
    auth.uid(),
    OLD.status,
    NEW.status,
    OLD.payment_status,
    NEW.payment_status,
    CASE
      WHEN NEW.status = 'processing' THEN 'Order confirmed and processing started'
      WHEN NEW.status = 'shipped' THEN 'Order shipped - Tracking: ' || COALESCE(NEW.tracking_number, 'N/A')
      WHEN NEW.status = 'delivered' THEN 'Order delivered'
      WHEN NEW.status = 'cancelled' THEN 'Order cancelled'
      ELSE NULL
    END
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for audit logging
CREATE TRIGGER log_order_status_changes
  AFTER UPDATE OF status, payment_status ON orders
  FOR EACH ROW
  WHEN (
    NEW.status IS DISTINCT FROM OLD.status OR 
    NEW.payment_status IS DISTINCT FROM OLD.payment_status
  )
  EXECUTE FUNCTION create_order_audit_log();

-- Enhanced order processing function
CREATE OR REPLACE FUNCTION process_order(
  p_items JSONB,
  p_shipping_address_id UUID,
  p_payment_method TEXT
) RETURNS UUID AS $$
DECLARE
  v_order_id UUID;
  v_order_number TEXT;
  v_totals RECORD;
BEGIN
  -- Validate order data
  PERFORM validate_order(p_items, p_shipping_address_id);
  
  -- Calculate totals
  SELECT * INTO v_totals 
  FROM calculate_order_totals(p_items, p_shipping_address_id);
  
  -- Generate order number
  v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || FLOOR(RANDOM() * 10000)::TEXT;
  
  -- Create order
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
  
  RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;