/*
  # Initial Data Setup
  
  1. Initial Data
    - Create default categories
    - Create sample products
    - Create test users for each role (admin, agent, customer)
    - Set up initial agent relationships
*/

-- Insert default categories
INSERT INTO categories (name, description, image_url) VALUES
  ('Electronics', 'Latest gadgets and electronic devices', 'https://images.pexels.com/photos/325153/pexels-photo-325153.jpeg'),
  ('Clothing', 'Fashion items for all occasions', 'https://images.pexels.com/photos/934063/pexels-photo-934063.jpeg'),
  ('Home & Kitchen', 'Everything you need for your home', 'https://images.pexels.com/photos/1643383/pexels-photo-1643383.jpeg'),
  ('Beauty', 'Skincare, makeup, and personal care', 'https://images.pexels.com/photos/3373736/pexels-photo-3373736.jpeg'),
  ('Sports', 'Sporting goods and fitness equipment', 'https://images.pexels.com/photos/3755440/pexels-photo-3755440.jpeg');

-- Insert sample products
INSERT INTO products (name, description, price, images, category_id, inventory, discount, featured) VALUES
  ('Smartphone X Pro', 'Latest smartphone with advanced features', 999.99, ARRAY['https://images.pexels.com/photos/1647976/pexels-photo-1647976.jpeg'], (SELECT id FROM categories WHERE name = 'Electronics'), 50, 10, true),
  ('Wireless Headphones', 'Premium noise-cancelling headphones', 249.99, ARRAY['https://images.pexels.com/photos/577769/pexels-photo-577769.jpeg'], (SELECT id FROM categories WHERE name = 'Electronics'), 100, NULL, true),
  ('Cotton T-Shirt', 'Comfortable 100% organic cotton t-shirt', 24.99, ARRAY['https://images.pexels.com/photos/428340/pexels-photo-428340.jpeg'], (SELECT id FROM categories WHERE name = 'Clothing'), 200, NULL, false),
  ('Smart Coffee Maker', 'WiFi-enabled programmable coffee maker', 149.99, ARRAY['https://images.pexels.com/photos/6316056/pexels-photo-6316056.jpeg'], (SELECT id FROM categories WHERE name = 'Home & Kitchen'), 75, 20, true);

-- Create test users (these will be created via API)
-- Admin: admin@example.com / password
-- Agent: agent@example.com / password
-- Customer: user@example.com / password

-- Set up agent relationships and commissions
INSERT INTO agents (user_id, level, commission_rate, status)
SELECT 
  id,
  2,
  10.0,
  'active'
FROM auth.users 
WHERE email = 'agent@example.com';

-- Create a sample order for testing
WITH sample_order AS (
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
    'ORD-001',
    id,
    'delivered',
    'credit_card',
    'completed',
    1249.98,
    100.00,
    0.00,
    1349.98
  FROM auth.users
  WHERE email = 'user@example.com'
  RETURNING id
)
INSERT INTO order_items (order_id, product_id, quantity, price)
SELECT
  so.id,
  p.id,
  1,
  p.price
FROM sample_order so
CROSS JOIN products p
WHERE p.name IN ('Smartphone X Pro', 'Wireless Headphones');