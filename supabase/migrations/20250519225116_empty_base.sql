/*
  # Fix Orders RLS Policies
  
  1. Changes
    - Drop existing policies if they exist
    - Recreate policies with proper permissions
    - Ensure users can create and manage their own orders
*/

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can create orders during checkout" ON orders;
DROP POLICY IF EXISTS "Users can update their own pending orders" ON orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;

-- Create policies for order management
CREATE POLICY "Users can create orders during checkout"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id 
  AND status = 'pending' 
  AND payment_status = 'pending'
);

CREATE POLICY "Users can update their own pending orders"
ON orders
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id 
  AND status = 'pending'
)
WITH CHECK (
  auth.uid() = user_id 
  AND status = 'pending'
);

CREATE POLICY "Users can view their own orders"
ON orders
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);