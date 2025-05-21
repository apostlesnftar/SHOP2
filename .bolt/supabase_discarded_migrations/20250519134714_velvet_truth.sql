/*
  # Fix create_order function
  
  1. Changes
    - Fix loop variable declaration for jsonb_array_elements
    - Add proper variable declarations
    - Improve error handling
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS create_order(jsonb[], uuid, text);
DROP FUNCTION IF EXISTS create_order(jsonb, uuid, text);

-- Create new create_order function with single jsonb parameter
CREATE OR REPLACE FUNCTION create_order(p_params jsonb)
RETURNS jsonb
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
  v_product_id uuid;
  v_quantity integer;
  v_product_price numeric(10,2);
  v_product_inventory integer;
  v_shipping_address_id uuid;
  v_payment_method text;
  v_items jsonb;
  v_item record;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Extract parameters
  v_items := p_params->'items';
  v_shipping_address_id := (p_params->>'shipping_address_id')::uuid;
  v_payment_method := p_params->>'payment_method';
  
  -- Validate required parameters
  IF v_items IS NULL OR v_shipping_address_id IS NULL OR v_payment_method IS NULL THEN
    RAISE EXCEPTION 'Missing required parameters';
  END IF;
  
  -- Validate user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;

  -- Validate shipping address belongs to user
  IF NOT EXISTS (
    SELECT 1 FROM addresses 
    WHERE id = v_shipping_address_id 
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Invalid shipping address';
  END IF;

  -- Initialize totals
  v_subtotal := 0;
  
  -- Validate items and calculate subtotal
  FOR v_item IN 
    SELECT value->>'product_id' as product_id, 
           (value->>'quantity')::integer as quantity 
    FROM jsonb_array_elements(v_items) as value
  LOOP
    v_product_id := v_item.product_id::uuid;
    v_quantity := v_item.quantity;
    
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
  
  -- Generate order number
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
    v_shipping_address_id,
    v_payment_method,
    'pending',
    v_subtotal,
    v_tax,
    v_shipping,
    v_total
  ) RETURNING id INTO v_order_id;
  
  -- Create order items
  FOR v_item IN 
    SELECT value->>'product_id' as product_id, 
           (value->>'quantity')::integer as quantity 
    FROM jsonb_array_elements(v_items) as value
  LOOP
    v_product_id := v_item.product_id::uuid;
    v_quantity := v_item.quantity;
    
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
    RAISE;
END;
$$;