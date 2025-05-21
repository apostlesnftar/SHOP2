/*
  # Update orders table RLS policies

  1. Changes
    - Modify the INSERT policy for orders to allow authenticated users to create orders
    - Ensure proper conditions for order creation during checkout
    - Maintain existing security constraints

  2. Security
    - Users can only create orders for themselves
    - Payment status and order status must be 'pending' initially
    - Maintain existing policies for other operations
*/

-- Drop the existing INSERT policy
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;

-- Create new INSERT policy with proper conditions
CREATE POLICY "Users can create orders during checkout"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND 
  status = 'pending' AND 
  payment_status = 'pending'
);