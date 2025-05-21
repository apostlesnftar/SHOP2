/*
  # Row Level Security Policies
  
  1. Security
    - Create policies for each table
    - Define access control based on user roles
    - Set up appropriate permissions for admins, agents, and customers
*/

-- Admin role function
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT role = 'admin'
    FROM user_profiles
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Agent role function
CREATE OR REPLACE FUNCTION is_agent()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT role = 'agent'
    FROM user_profiles
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. Categories Policies
CREATE POLICY "Categories are viewable by everyone" ON categories
  FOR SELECT USING (true);

CREATE POLICY "Categories can be created by admins" ON categories
  FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "Categories can be updated by admins" ON categories
  FOR UPDATE USING (is_admin());

CREATE POLICY "Categories can be deleted by admins" ON categories
  FOR DELETE USING (is_admin());

-- 2. Products Policies
CREATE POLICY "Products are viewable by everyone" ON products
  FOR SELECT USING (true);

CREATE POLICY "Products can be created by admins" ON products
  FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "Products can be updated by admins" ON products
  FOR UPDATE USING (is_admin());

CREATE POLICY "Products can be deleted by admins" ON products
  FOR DELETE USING (is_admin());

-- 3. User Profiles Policies
CREATE POLICY "Users can view their own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles" ON user_profiles
  FOR SELECT USING (is_admin());

CREATE POLICY "Agents can view their team members' profiles" ON user_profiles
  FOR SELECT USING (
    is_agent() AND (
      -- Check if the profile belongs to a user that is part of the agent's team
      EXISTS (
        SELECT 1 FROM agents a1
        JOIN agents a2 ON a2.parent_agent_id = a1.user_id
        WHERE a1.user_id = auth.uid() AND a2.user_id = user_profiles.id
      )
    )
  );

CREATE POLICY "Users can update their own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can update all profiles" ON user_profiles
  FOR UPDATE USING (is_admin());

-- 4. Addresses Policies
CREATE POLICY "Users can view their own addresses" ON addresses
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all addresses" ON addresses
  FOR SELECT USING (is_admin());

CREATE POLICY "Users can insert their own addresses" ON addresses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own addresses" ON addresses
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own addresses" ON addresses
  FOR DELETE USING (auth.uid() = user_id);

-- 5. Orders Policies
CREATE POLICY "Users can view their own orders" ON orders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all orders" ON orders
  FOR SELECT USING (is_admin());

CREATE POLICY "Agents can view orders they earned commission on" ON orders
  FOR SELECT USING (
    is_agent() AND (
      EXISTS (
        SELECT 1 FROM commissions
        WHERE agent_id = auth.uid() AND order_id = orders.id
      )
    )
  );

CREATE POLICY "Users can create their own orders" ON orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pending orders" ON orders
  FOR UPDATE USING (
    auth.uid() = user_id AND status = 'pending'
  );

CREATE POLICY "Admins can update any order" ON orders
  FOR UPDATE USING (is_admin());

-- 6. Order Items Policies
CREATE POLICY "Users can view their own order items" ON order_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can view all order items" ON order_items
  FOR SELECT USING (is_admin());

CREATE POLICY "Agents can view order items they earned commission on" ON order_items
  FOR SELECT USING (
    is_agent() AND (
      EXISTS (
        SELECT 1 FROM orders
        JOIN commissions ON orders.id = commissions.order_id
        WHERE orders.id = order_items.order_id AND commissions.agent_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can insert items to their own orders" ON order_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid() AND orders.status = 'pending'
    )
  );

-- 7. Agents Policies
CREATE POLICY "Agents can view their own profile" ON agents
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all agents" ON agents
  FOR SELECT USING (is_admin());

CREATE POLICY "Agents can view their team members" ON agents
  FOR SELECT USING (
    auth.uid() = parent_agent_id OR
    user_id = auth.uid() OR
    is_admin()
  );

CREATE POLICY "Admins can insert agents" ON agents
  FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "Admins can update agents" ON agents
  FOR UPDATE USING (is_admin());

-- 8. Commissions Policies
CREATE POLICY "Agents can view their own commissions" ON commissions
  FOR SELECT USING (auth.uid() = agent_id);

CREATE POLICY "Admins can view all commissions" ON commissions
  FOR SELECT USING (is_admin());

CREATE POLICY "System can insert commissions" ON commissions
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND (
      is_admin() OR
      -- For automated commission creation, we might need a service role
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_id AND orders.status = 'completed')
    )
  );

CREATE POLICY "Admins can update commissions" ON commissions
  FOR UPDATE USING (is_admin());

-- 9. Shared Orders Policies
CREATE POLICY "Anyone can view valid shared orders" ON shared_orders
  FOR SELECT USING (expires_at > now() AND status = 'pending');

CREATE POLICY "Users can create shared orders for their own orders" ON shared_orders
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can view all shared orders" ON shared_orders
  FOR SELECT USING (is_admin());

CREATE POLICY "Users can view shared orders they created" ON shared_orders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shared_orders.order_id AND orders.user_id = auth.uid()
    )
  );

-- 10. Wishlists Policies
CREATE POLICY "Users can view their own wishlist" ON wishlists
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert items to their own wishlist" ON wishlists
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete items from their own wishlist" ON wishlists
  FOR DELETE USING (auth.uid() = user_id);