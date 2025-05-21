/*
  # Fix Orders RLS Policy
  
  1. Changes
    - Drop existing INSERT policies for orders table
    - Create new policy that allows both authenticated and unauthenticated users to create orders
    - Maintain existing policies for SELECT and UPDATE operations
*/

-- Drop existing INSERT policies to avoid conflicts
DROP POLICY IF EXISTS "Users can create orders" ON orders;
DROP POLICY IF EXISTS "Allow order creation" ON orders;

-- Create new policy that allows public access for order creation
CREATE POLICY "Allow public order creation"
ON orders
FOR INSERT
TO public
WITH CHECK (true);

-- Add a comment explaining the policy
COMMENT ON POLICY "Allow public order creation" ON orders
IS 'Allows both authenticated and unauthenticated users to create orders. This is necessary for guest checkout functionality.';

-- Ensure other policies remain intact
DO $$
BEGIN
  -- Recreate SELECT policies if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND cmd = 'SELECT'
    AND policyname = 'Users can view their own orders'
  ) THEN
    CREATE POLICY "Users can view their own orders"
    ON orders
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND cmd = 'SELECT'
    AND policyname = 'Admins can view all orders'
  ) THEN
    CREATE POLICY "Admins can view all orders"
    ON orders
    FOR SELECT
    TO authenticated
    USING (is_admin());
  END IF;

  -- Recreate UPDATE policies if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND cmd = 'UPDATE'
    AND policyname = 'Users can update their own pending orders'
  ) THEN
    CREATE POLICY "Users can update their own pending orders"
    ON orders
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id AND status = 'pending')
    WITH CHECK (auth.uid() = user_id AND status = 'pending');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND cmd = 'UPDATE'
    AND policyname = 'Admins can update any order'
  ) THEN
    CREATE POLICY "Admins can update any order"
    ON orders
    FOR UPDATE
    TO authenticated
    USING (is_admin());
  END IF;
END $$;