/*
  # Add admin policy for orders
  
  1. Changes
    - Add policy allowing admins to create orders for any user
    - Ensures admins have full access to create orders
*/

-- Create policy for admins to create orders for any user
CREATE POLICY "Admins can create orders for any user"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());