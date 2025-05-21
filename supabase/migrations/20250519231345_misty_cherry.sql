/*
  # Fix Orders RLS Policy for Public Users
  
  1. Changes
    - Add policy to allow public (unauthenticated) users to create orders
    - Ensure proper access control for order creation
    - Fix the "new row violates row-level security policy for table orders" error
*/

-- Drop existing INSERT policies to avoid conflicts
DROP POLICY IF EXISTS "Allow public order creation" ON orders;
DROP POLICY IF EXISTS "Users can create orders" ON orders;

-- Create new policy that allows public access for order creation
CREATE POLICY "Allow public order creation"
ON orders
FOR INSERT
TO public
WITH CHECK (true);

-- Add a comment explaining the policy
COMMENT ON POLICY "Allow public order creation" ON orders
IS 'Allows both authenticated and unauthenticated users to create orders. This is necessary for guest checkout functionality.';