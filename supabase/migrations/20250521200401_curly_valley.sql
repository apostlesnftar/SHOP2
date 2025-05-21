-- Add policies for anonymous users to access shared orders
DO $$
BEGIN
  -- Check if the policy exists before creating it
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'shared_orders' 
    AND policyname = 'Allow anon select on shared_orders'
  ) THEN
    CREATE POLICY "Allow anon select on shared_orders" 
    ON shared_orders 
    FOR SELECT 
    TO anon 
    USING (true);
  END IF;

  -- Check if the policy exists before creating it
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'shared_orders' 
    AND policyname = 'Allow anon update on shared_orders'
  ) THEN
    CREATE POLICY "Allow anon update on shared_orders" 
    ON shared_orders 
    FOR UPDATE 
    TO anon 
    USING (true);
  END IF;

  -- Check if the policy exists before creating it
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND policyname = 'Allow anon select on orders'
  ) THEN
    CREATE POLICY "Allow anon select on orders" 
    ON orders 
    FOR SELECT 
    TO anon 
    USING (true);
  END IF;

  -- Check if the policy exists before creating it
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND policyname = 'Allow anon update on orders'
  ) THEN
    CREATE POLICY "Allow anon update on orders" 
    ON orders 
    FOR UPDATE 
    TO anon 
    USING (true);
  END IF;
END
$$;