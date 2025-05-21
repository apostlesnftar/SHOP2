/*
  # Add payment gateway RLS policies

  1. Changes
    - Add RLS policies for payment_gateways table to allow:
      - Public users to view active payment gateways
      - Authenticated admins to manage payment gateways
      - Authenticated users to view active payment gateways

  2. Security
    - Enable RLS on payment_gateways table
    - Add policies for different access levels
*/

-- Enable RLS
ALTER TABLE payment_gateways ENABLE ROW LEVEL SECURITY;

-- Allow public users to view active payment gateways
CREATE POLICY "Allow public to view active payment gateways"
ON payment_gateways
FOR SELECT
TO public
USING (is_active = true);

-- Allow authenticated admins to manage payment gateways
CREATE POLICY "Allow admins to manage payment gateways"
ON payment_gateways
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Allow authenticated users to view active payment gateways
CREATE POLICY "Allow authenticated users to view active payment gateways"
ON payment_gateways
FOR SELECT
TO authenticated
USING (is_active = true);