/*
  # Improve Friend Payment Processing
  
  1. Changes
    - Create a new version of process_friend_payment function
    - Ensure proper referrer identification for order creators
    - Allow anonymous users to process payments
    - Update order status and calculate commissions correctly
    
  2. Security
    - Maintain existing security context
    - Grant permissions to both authenticated and anonymous users
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS process_friend_payment(text, text);

-- Create updated function with proper referrer handling
CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_order_total numeric;
  v_order_number text;
  v_referrer_id uuid;
  v_agent_commission_rate numeric;
  v_agent_commission numeric;
  v_parent_agent_id uuid;
  v_parent_commission_rate numeric;
  v_parent_commission numeric;
  v_transaction_id uuid;
  v_parent_transaction_id uuid;
  v_payment_method_normalized text;
BEGIN
  -- Normalize payment method (lowercase and replace spaces with underscores)
  v_payment_method_normalized := LOWER(REPLACE(p_payment_method, ' ', '_'));
  
  -- Get shared order with explicit column selection
  SELECT 
    so.order_id,
    o.order_number,
    o.user_id,
    o.total
  INTO 
    v_order_id,
    v_order_number,
    v_user_id,
    v_order_total
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
  AND so.expires_at > now()
  AND so.status = 'pending'
  AND o.payment_method = 'friend_payment'
  AND o.payment_status = 'pending';
  
  -- Validate shared order
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found, expired, or already paid'
    );
  END IF;
  
  -- Get referrer_id from user_profiles with explicit table reference
  SELECT up.referrer_id INTO v_referrer_id
  FROM user_profiles up
  WHERE up.id = v_user_id;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing',
    payment_method = v_payment_method_normalized
  WHERE id = v_order_id
  AND payment_status = 'pending';
  
  -- Create audit log
  INSERT INTO order_audit_logs (
    order_id,
    user_id,
    old_status,
    new_status,
    old_payment_status,
    new_payment_status,
    notes
  ) VALUES (
    v_order_id,
    v_user_id,
    'pending',
    'processing',
    'pending',
    'completed',
    'Order payment completed via shared payment link using ' || p_payment_method
  );
  
  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = now()
  WHERE share_id = p_share_id;
  
  -- If user has a referrer, create commission for the referrer
  IF v_referrer_id IS NOT NULL THEN
    -- Get the referrer's commission rate and parent
    SELECT a.commission_rate, a.parent_agent_id 
    INTO v_agent_commission_rate, v_parent_agent_id
    FROM agents a
    WHERE a.user_id = v_referrer_id
    AND a.status = 'active';
    
    -- If referrer is an active agent, calculate commission
    IF v_agent_commission_rate IS NOT NULL THEN
      -- Calculate commission
      v_agent_commission := (v_order_total * v_agent_commission_rate / 100);
      
      -- Create commission record
      INSERT INTO commissions (agent_id, order_id, amount, status)
      VALUES (v_referrer_id, v_order_id, v_agent_commission, 'pending');
      
      -- Create wallet transaction record
      INSERT INTO wallet_transactions (
        agent_id,
        amount,
        type,
        status,
        reference_id,
        notes,
        completed_at
      ) VALUES (
        v_referrer_id,
        v_agent_commission,
        'commission',
        'completed',
        v_order_id,
        'Commission from shared order #' || v_order_number,
        NOW()
      ) RETURNING id INTO v_transaction_id;
      
      -- Update agent total earnings and balance
      UPDATE agents
      SET total_earnings = total_earnings + v_agent_commission,
          current_balance = current_balance + v_agent_commission
      WHERE user_id = v_referrer_id;
      
      -- If there's a parent agent, calculate their commission too
      IF v_parent_agent_id IS NOT NULL THEN
        -- Get parent's commission rate
        SELECT a.commission_rate INTO v_parent_commission_rate
        FROM agents a 
        WHERE a.user_id = v_parent_agent_id
        AND a.status = 'active';
        
        IF v_parent_commission_rate IS NOT NULL THEN
          v_parent_commission := (v_order_total * v_parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (v_parent_agent_id, v_order_id, v_parent_commission, 'pending');
          
          -- Create wallet transaction record for parent
          INSERT INTO wallet_transactions (
            agent_id,
            amount,
            type,
            status,
            reference_id,
            notes,
            completed_at
          ) VALUES (
            v_parent_agent_id,
            v_parent_commission,
            'commission',
            'completed',
            v_order_id,
            'Team commission from shared order #' || v_order_number,
            NOW()
          ) RETURNING id INTO v_parent_transaction_id;
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + v_parent_commission,
              current_balance = current_balance + v_parent_commission
          WHERE user_id = v_parent_agent_id;
        END IF;
      END IF;
    END IF;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_number', v_order_number
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG 'Error in process_friend_payment: %', SQLERRM;
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

-- Grant execute permissions to both authenticated and anonymous users
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO anon;

-- Ensure policies exist for anonymous users to access shared orders
DO $$
BEGIN
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