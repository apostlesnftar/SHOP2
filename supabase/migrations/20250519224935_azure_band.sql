/*
  # Add Order Audit Logs Policy
  
  1. Changes
    - Add policy to allow system to create audit logs for orders
*/

-- Order Audit Logs Policies
CREATE POLICY "System can create order audit logs"
  ON order_audit_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_audit_logs.order_id
      AND (
        orders.user_id = auth.uid()
        OR is_admin()
      )
    )
  );