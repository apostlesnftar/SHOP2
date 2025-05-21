/*
  # Fix orders and user profiles relationship
  
  1. Changes
    - Check for existing constraint before adding
    - Update RLS policies for proper access control
*/

-- Check and add foreign key constraint if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'orders_user_id_fkey'
    AND table_name = 'orders'
  ) THEN
    ALTER TABLE orders
    ADD CONSTRAINT orders_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES user_profiles(id)
    ON DELETE CASCADE;
  END IF;
END $$;

-- Update RLS policies for orders to include user profile access
DROP POLICY IF EXISTS "Admins can view all orders" ON orders;
CREATE POLICY "Admins can view all orders" ON orders
  FOR SELECT USING (is_admin());

DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
CREATE POLICY "Users can view their own orders" ON orders
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Agents can view orders they earned commission on" ON orders;
CREATE POLICY "Agents can view orders they earned commission on" ON orders
  FOR SELECT USING (
    is_agent() AND (
      EXISTS (
        SELECT 1 FROM commissions
        WHERE agent_id = auth.uid() AND order_id = orders.id
      )
    )
  );