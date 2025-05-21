/*
  # Fix Orders RLS Policy
  
  1. Changes
    - Drop existing policy for order creation
    - Create new policy with proper permissions
    - Ensure authenticated users can create orders with their own user_id
*/

-- First drop the existing policy if it exists
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;

-- Create new policy with proper permissions
CREATE POLICY "Users can insert their own orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);