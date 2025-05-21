/*
  # Fix orders policy for user creation
  
  1. Changes
    - Drop existing policy if it exists
    - Create policy for users to create their own orders
*/

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;

-- Create policy for users to create their own orders
CREATE POLICY "Users can create their own orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);