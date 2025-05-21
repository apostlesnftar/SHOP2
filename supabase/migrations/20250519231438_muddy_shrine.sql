/*
  # Fix Orders RLS Policy for Public Access
  
  1. Changes
    - Add policy to allow public users to create orders
    - This fixes the checkout process for both authenticated and unauthenticated users
    - Ensures proper access control while enabling guest checkout functionality
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