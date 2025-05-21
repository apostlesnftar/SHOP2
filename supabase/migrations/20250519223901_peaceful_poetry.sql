/*
  # Fix orders RLS policy
  
  1. Changes
    - Drop existing policy if it exists
    - Recreate policy with proper checks
*/

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;

-- Add policy for authenticated users to create orders
CREATE POLICY "Users can create their own orders"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND
  status = 'pending' AND
  payment_status = 'pending'
);