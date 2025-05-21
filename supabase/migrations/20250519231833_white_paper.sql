-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow public order creation" ON orders;

-- Create new policy for order creation
CREATE POLICY "Allow public order creation"
ON orders
FOR INSERT
TO public
WITH CHECK (true);

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can create their own orders" ON orders;

-- Create policy for authenticated users to create orders
CREATE POLICY "Users can create their own orders"
ON orders
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND 
  status = 'pending' AND 
  payment_status = 'pending'
);