/*
  # Fix orders and user profiles relationship
  
  1. Changes
    - Drop existing foreign key if it exists
    - Add correct foreign key to auth.users instead of user_profiles
    - Update RLS policies
*/

-- First drop the existing foreign key if it exists
ALTER TABLE orders
DROP CONSTRAINT IF EXISTS orders_user_id_fkey;

-- Add the correct foreign key to auth.users
ALTER TABLE orders
ADD CONSTRAINT orders_user_id_fkey
FOREIGN KEY (user_id) REFERENCES auth.users(id)
ON DELETE CASCADE;

-- Update RLS policies for orders
DROP POLICY IF EXISTS "Admins can view all orders" ON orders;
CREATE POLICY "Admins can view all orders" ON orders
  FOR SELECT USING (is_admin());

DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
CREATE POLICY "Users can view their own orders" ON orders
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Agents can view orders they earned commission on" ON orders;
CREATE POLICY "Agents can view orders they earned commission on" ON orders
  FOR SELECT USING (
    is_agent() AND (
      EXISTS (
        SELECT 1 FROM commissions
        WHERE agent_id = auth.uid() AND order_id = orders.id
      )
    )
  );