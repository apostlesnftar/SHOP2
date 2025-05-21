/*
  # Fix orders table RLS policies

  1. Changes
    - Update RLS policies for orders table to allow authenticated users to create orders
    - Add policy for users to insert their own orders with pending status
    - Ensure payment_status and status fields have correct default values

  2. Security
    - Users can only create orders for themselves
    - Orders must start with 'pending' status
    - Payment status must be 'pending' initially
*/

-- Drop existing insert policies to avoid conflicts
DROP POLICY IF EXISTS "Users can insert their own orders" ON orders;
DROP POLICY IF EXISTS "Admins can create orders for any user" ON orders;

-- Create new insert policy for users
CREATE POLICY "Users can create their own orders"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND
  status = 'pending' AND
  payment_status = 'pending'
);

-- Ensure default values are set correctly
ALTER TABLE orders 
ALTER COLUMN status SET DEFAULT 'pending',
ALTER COLUMN payment_status SET DEFAULT 'pending';

-- Refresh existing policies to ensure they work with new changes
DO $$
BEGIN
  -- Recreate admin policies
  DROP POLICY IF EXISTS "Admins have full access to orders" ON orders;
  CREATE POLICY "Admins have full access to orders"
    ON orders
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

  -- Ensure users can view their own orders
  DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
  CREATE POLICY "Users can view their own orders"
    ON orders
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

  -- Allow users to update their pending orders
  DROP POLICY IF EXISTS "Users can update their own pending orders" ON orders;
  CREATE POLICY "Users can update their own pending orders"
    ON orders
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id AND status = 'pending')
    WITH CHECK (auth.uid() = user_id AND status = 'pending');
END $$;