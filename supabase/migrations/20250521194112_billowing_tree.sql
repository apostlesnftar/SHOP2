/*
  # Add order creation policy for authenticated users

  1. Security Changes
    - Add RLS policy to allow authenticated users to create orders
    - Policy ensures users can only create orders with their own user_id
    - Maintains existing security model while enabling order creation functionality

  Note: This policy complements existing policies without modifying them
*/

CREATE POLICY "Users can create their own orders"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
);