/*
  # Create Order Details View
  
  1. New View
    - Creates order_details view for displaying order information with user details
    - Includes order items and product information
    - Adds necessary indexes for performance
    - Sets up proper access control
*/

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

-- Grant access to the view
GRANT SELECT ON order_details TO authenticated;

-- Create function to check view access
CREATE OR REPLACE FUNCTION check_order_details_access(order_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    -- Admin can view all orders
    (SELECT is_admin()) OR
    -- Users can view their own orders
    (auth.uid() = order_user_id) OR
    -- Agents can view orders they earned commission on
    (
      (SELECT is_agent()) AND
      EXISTS (
        SELECT 1 FROM commissions
        WHERE agent_id = auth.uid() 
        AND order_id IN (
          SELECT id FROM orders WHERE user_id = order_user_id
        )
      )
    )
  );
END;
$$;