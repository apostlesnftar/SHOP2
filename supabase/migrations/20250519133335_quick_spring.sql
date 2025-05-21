/*
  # Add create_order function
  
  1. New Functions
    - `create_order`: Creates a new order with the provided items and shipping details
      - Parameters:
        - p_items: Array of order items (product_id, quantity)
        - p_shipping_address_id: UUID of the shipping address
        - p_payment_method: Text indicating payment method
      - Returns: Record containing order_id and order_number
      
  2. Security
    - Function is accessible to authenticated users only
    - Validates input parameters
    - Checks product inventory
    - Calculates order totals
    
  3. Functionality
    - Generates unique order number
    - Creates order record
    - Creates order items
    - Handles inventory checks
    - Calculates subtotal, tax, shipping, and total
*/

CREATE OR REPLACE FUNCTION create_order(
  p_items jsonb[],
  p_shipping_address_id uuid,
  p_payment_method text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric(10,2);
  v_tax numeric(10,2);
  v_shipping numeric(10,2);
  v_total numeric(10,2);
  v_item jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_product_price numeric(10,2);
  v_product_inventory integer;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Validate user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;

  -- Validate shipping address belongs to user
  IF NOT EXISTS (
    SELECT 1 FROM addresses 
    WHERE id = p_shipping_address_id 
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Invalid shipping address';
  END IF;

  -- Initialize totals
  v_subtotal := 0;
  v_shipping := CASE WHEN v_subtotal > 50 THEN 0 ELSE 10 END;
  
  -- Validate items and calculate subtotal
  FOR v_item IN SELECT * FROM unnest(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;
    
    -- Get product details
    SELECT price, inventory 
    INTO v_product_price, v_product_inventory
    FROM products 
    WHERE id = v_product_id;
    
    -- Check if product exists
    IF v_product_price IS NULL THEN
      RAISE EXCEPTION 'Product not found: %', v_product_id;
    END IF;
    
    -- Check inventory
    IF v_product_inventory < v_quantity THEN
      RAISE EXCEPTION 'Insufficient inventory for product: %', v_product_id;
    END IF;
    
    -- Add to subtotal
    v_subtotal := v_subtotal + (v_product_price * v_quantity);
  END LOOP;
  
  -- Calculate tax and total
  v_tax := v_subtotal * 0.08; -- 8% tax rate
  v_shipping := CASE WHEN v_subtotal > 50 THEN 0 ELSE 10 END;
  v_total := v_subtotal + v_tax + v_shipping;
  
  -- Generate order number (current timestamp in milliseconds)
  v_order_number := 'ORD-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS');
  
  -- Create order
  INSERT INTO orders (
    user_id,
    order_number,
    shipping_address_id,
    payment_method,
    payment_status,
    subtotal,
    tax,
    shipping,
    total
  ) VALUES (
    v_user_id,
    v_order_number,
    p_shipping_address_id,
    p_payment_method,
    'pending',
    v_subtotal,
    v_tax,
    v_shipping,
    v_total
  ) RETURNING id INTO v_order_id;
  
  -- Create order items
  FOR v_item IN SELECT * FROM unnest(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;
    
    -- Get current price
    SELECT price INTO v_product_price
    FROM products 
    WHERE id = v_product_id;
    
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
      v_product_price
    );
  END LOOP;
  
  -- Return order details
  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error details if needed
    RAISE;
END;
$$;