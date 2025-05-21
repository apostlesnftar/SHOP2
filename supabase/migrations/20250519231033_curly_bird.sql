/*
  # Fix Orders RLS Policies
  
  1. Changes
    - Drop existing RLS policies for orders table
    - Create new policies with proper authentication checks
    - Ensure only authenticated users can create orders
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Allow order creation" ON orders;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON orders;
DROP POLICY IF EXISTS "Agents can view orders they earned commission on" ON orders;
DROP POLICY IF EXISTS "Users can update their own pending orders" ON orders;
DROP POLICY IF EXISTS "Admins can update any order" ON orders;

-- Create new policies with proper authentication checks
CREATE POLICY "Users can create orders"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own orders"
ON orders
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own pending orders"
ON orders
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id AND status = 'pending')
WITH CHECK (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "Admins can view all orders"
ON orders
FOR SELECT
TO authenticated
USING (is_admin());

CREATE POLICY "Admins can update any order"
ON orders
FOR UPDATE
TO authenticated
USING (is_admin());

CREATE POLICY "Agents can view orders they earned commission on"
ON orders
FOR SELECT
TO authenticated
USING (
  is_agent() AND (
    EXISTS (
      SELECT 1 FROM commissions
      WHERE agent_id = auth.uid() AND order_id = orders.id
    )
  )
);