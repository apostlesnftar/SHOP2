-- Set proper security context
SET LOCAL search_path TO public;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can view all orders" ON orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
DROP POLICY IF EXISTS "Agents can view orders they earned commission on" ON orders;

-- Create order_details view
CREATE OR REPLACE VIEW order_details AS
SELECT 
  o.*,
  up.username,
  up.full_name,
  (
    SELECT json_agg(
      jsonb_build_object(
        'id', oi.id,
        'product_id', oi.product_id,
        'quantity', oi.quantity,
        'price', oi.price,
        'product', (
          SELECT jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'description', p.description,
            'images', p.images
          )
          FROM products p
          WHERE p.id = oi.product_id
        )
      )
    )
    FROM order_items oi
    WHERE oi.order_id = o.id
  ) AS order_items
FROM orders o
LEFT JOIN user_profiles up ON o.user_id = up.id;

-- Add indexes for better join performance
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_id ON user_profiles(id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- Enable RLS on the view
ALTER VIEW order_details SET (security_invoker = on);

-- Create RLS policies for the view
CREATE POLICY "Admins can view all orders" ON orders
  FOR SELECT
  USING (is_admin());

CREATE POLICY "Users can view their own orders" ON orders
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Agents can view orders they earned commission on" ON orders
  FOR SELECT
  USING (
    is_agent() AND (
      EXISTS (
        SELECT 1 FROM commissions
        WHERE agent_id = auth.uid() AND order_id = id
      )
    )
  );