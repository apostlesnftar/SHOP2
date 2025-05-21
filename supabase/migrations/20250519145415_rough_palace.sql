/*
  # Add admin permissions
  
  1. Security
    - Create is_admin() function
    - Add policies for admin access to all tables
*/

-- Create is_admin function
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM user_profiles 
    WHERE id = auth.uid() 
    AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Categories policies
CREATE POLICY "Admins have full access to categories" ON categories
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Products policies
CREATE POLICY "Admins have full access to products" ON products
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- User Profiles policies
CREATE POLICY "Admins have full access to user profiles" ON user_profiles
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Addresses policies
CREATE POLICY "Admins have full access to addresses" ON addresses
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Orders policies
CREATE POLICY "Admins have full access to orders" ON orders
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Order Items policies
CREATE POLICY "Admins have full access to order items" ON order_items
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Agents policies
CREATE POLICY "Admins have full access to agents" ON agents
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Commissions policies
CREATE POLICY "Admins have full access to commissions" ON commissions
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Shared Orders policies
CREATE POLICY "Admins have full access to shared orders" ON shared_orders
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Wishlists policies
CREATE POLICY "Admins have full access to wishlists" ON wishlists
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Order Audit Logs policies
CREATE POLICY "Admins have full access to order audit logs" ON order_audit_logs
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());