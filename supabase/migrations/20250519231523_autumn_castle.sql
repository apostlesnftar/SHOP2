/*
  # Add order creation policy

  1. Changes
    - Add a new RLS policy to allow authenticated users to create orders
    - Policy ensures users can only create orders for themselves
    - Validates initial order status and payment status

  2. Security
    - Restricts order creation to authenticated users only
    - Enforces user_id matches the authenticated user
    - Ensures orders start with 'pending' status
*/

CREATE POLICY "Users can create their own orders"
ON public.orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND 
  status = 'pending' AND 
  payment_status = 'pending'
);