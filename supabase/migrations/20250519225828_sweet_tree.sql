/*
  # Fix Orders RLS Policy
  
  1. Changes
    - Drop existing insert policies
    - Create new permissive policy for authenticated users
*/

-- Drop existing policies by name
DROP POLICY IF EXISTS "Users can create orders during checkout" ON orders;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON orders;
DROP POLICY IF EXISTS "Allow all users (temp)" ON orders;
DROP POLICY IF EXISTS "Insert for all authenticated users" ON orders;

-- Create new policy for order creation
CREATE POLICY "Allow order creation"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Add a comment explaining the policy
COMMENT ON POLICY "Allow order creation" ON orders
IS 'Allows all authenticated users to create orders. This is necessary for checkout functionality.';