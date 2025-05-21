/*
  # Fix orders RLS policy
  
  1. Changes
    - Drop existing policy if it exists
    - Recreate policy for order creation
*/

-- Drop existing policy
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;

-- Create policy for order creation
CREATE POLICY "Users can create their own orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);