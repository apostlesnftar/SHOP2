/*
  # Fix ambiguous referrer_id column reference

  1. Changes
    - Update process_friend_payment function to use explicit table references
    - Add table aliases for better readability
    - Fix ambiguous column references

  2. Security
    - No changes to security policies
    - Function remains accessible to authenticated users only
*/

CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_user_id uuid,
  p_payment_method text,
  p_payment_status text DEFAULT 'pending'
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_shared_order_id uuid;
BEGIN
  -- Get the shared order and related order details using explicit table references
  SELECT so.id, so.order_id INTO v_shared_order_id, v_order_id
  FROM shared_orders so
  WHERE so.share_id = p_share_id
    AND so.status = 'pending'
    AND so.expires_at > now();

  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired share ID';
  END IF;

  -- Update the shared order status with explicit table reference
  UPDATE shared_orders so
  SET status = 'completed',
      updated_at = now()
  WHERE so.id = v_shared_order_id;

  -- Create a new order for the friend with explicit table references
  WITH original_order AS (
    SELECT 
      o.subtotal,
      o.tax,
      o.shipping,
      o.total,
      so.referrer_id AS shared_order_referrer_id
    FROM orders o
    JOIN shared_orders so ON so.order_id = o.id
    WHERE o.id = v_order_id
  )
  INSERT INTO orders (
    order_number,
    user_id,
    status,
    payment_method,
    payment_status,
    subtotal,
    tax,
    shipping,
    total
  )
  SELECT
    'FP-' || substr(md5(random()::text), 1, 10),
    p_user_id,
    'pending',
    p_payment_method,
    p_payment_status,
    oo.subtotal,
    oo.tax,
    oo.shipping,
    oo.total
  FROM original_order oo
  RETURNING id INTO v_order_id;

  -- Copy order items with explicit table references
  INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    price
  )
  SELECT
    v_order_id,
    oi.product_id,
    oi.quantity,
    oi.price
  FROM order_items oi
  WHERE oi.order_id = (
    SELECT so.order_id 
    FROM shared_orders so 
    WHERE so.id = v_shared_order_id
  );

  RETURN v_order_id;
END;
$$;