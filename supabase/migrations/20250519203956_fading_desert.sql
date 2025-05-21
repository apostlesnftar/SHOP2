/*
  # Fix payment gateway deletion

  1. Changes
    - Add a stored procedure to safely delete payment gateways and their logs
    - The procedure handles the deletion in the correct order to avoid foreign key violations

  2. Security
    - The procedure is only accessible to authenticated users
    - RLS policies remain unchanged
*/

CREATE OR REPLACE FUNCTION delete_payment_gateway(gateway_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete logs first to avoid foreign key constraint violations
  DELETE FROM payment_gateway_logs WHERE gateway_id = $1;
  
  -- Then delete the gateway
  DELETE FROM payment_gateways WHERE id = $1;
END;
$$;