/*
  # Fix delete_payment_gateway function

  1. Changes
    - Update delete_payment_gateway function to use explicit table references
    - Fix ambiguous gateway_id column reference
    - Ensure proper cascading delete of related records

  2. Security
    - Function remains security definer to run with elevated privileges
    - Access control handled through RLS policies
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS delete_payment_gateway;

-- Recreate function with fixed column references
CREATE OR REPLACE FUNCTION delete_payment_gateway(gateway_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete payment gateway logs first (they reference the gateway)
  DELETE FROM payment_gateway_logs
  WHERE payment_gateway_logs.gateway_id = delete_payment_gateway.gateway_id;
  
  -- Delete the payment gateway itself
  DELETE FROM payment_gateways
  WHERE payment_gateways.id = delete_payment_gateway.gateway_id;
END;
$$;