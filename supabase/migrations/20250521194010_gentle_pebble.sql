/*
  # Fix Orders RLS Policy
  
  1. Changes
    - Add a more permissive policy for order creation
    - Allow public users to create orders during checkout
    - Fix the "new row violates row-level security policy for table orders" error
*/

-- Drop existing INSERT policies to avoid conflicts
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;
DROP POLICY IF EXISTS "Allow public order creation" ON orders;
DROP POLICY IF EXISTS "Users can create orders during checkout" ON orders;
DROP POLICY IF EXISTS "Allow order creation" ON orders;

-- Create a new, more permissive policy for order creation
CREATE POLICY "Allow public order creation"
ON orders
FOR INSERT
TO public
WITH CHECK (true);

-- Add a comment explaining the policy
COMMENT ON POLICY "Allow public order creation" ON orders
IS 'Allows both authenticated and unauthenticated users to create orders. This is necessary for guest checkout functionality.';