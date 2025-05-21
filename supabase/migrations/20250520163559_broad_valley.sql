/*
  # Agent Wallet System
  
  1. New Features
    - Add wallet_transactions table to track all wallet transactions
    - Add functions for admins to add/subtract from agent wallets
    - Add functions for agents to request withdrawals
    - Update agent dashboard to show wallet balance and transactions
    
  2. Security
    - Proper RLS policies to ensure only admins can modify balances
    - Transaction history for audit purposes
*/

-- Create wallet_transactions table
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL REFERENCES agents(user_id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'commission', 'adjustment')),
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'rejected', 'cancelled')),
  reference_id UUID, -- Optional reference to order or other entity
  notes TEXT,
  admin_id UUID REFERENCES auth.users(id), -- Admin who processed the transaction (if applicable)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- Enable RLS on wallet_transactions
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for wallet_transactions
CREATE POLICY "Agents can view their own wallet transactions"
  ON wallet_transactions
  FOR SELECT
  TO authenticated
  USING (agent_id = auth.uid());

CREATE POLICY "Admins can view all wallet transactions"
  ON wallet_transactions
  FOR SELECT
  TO authenticated
  USING (is_admin());

CREATE POLICY "Admins can insert wallet transactions"
  ON wallet_transactions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_admin() OR 
    (agent_id = auth.uid() AND type = 'withdrawal' AND status = 'pending')
  );

CREATE POLICY "Admins can update wallet transactions"
  ON wallet_transactions
  FOR UPDATE
  TO authenticated
  USING (is_admin());

-- Create trigger for updating timestamp
CREATE TRIGGER update_wallet_transactions_modtime
  BEFORE UPDATE ON wallet_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_modified_column();

-- Function for admin to add funds to agent wallet
CREATE OR REPLACE FUNCTION admin_add_agent_funds(
  p_agent_id UUID,
  p_amount NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_is_agent BOOLEAN;
  v_transaction_id UUID;
BEGIN
  -- Check if user is admin
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) INTO v_is_admin;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Only admins can add funds to agent wallets'
    );
  END IF;
  
  -- Check if agent exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Agent not found'
    );
  END IF;
  
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Amount must be greater than zero'
    );
  END IF;
  
  -- Create transaction record
  INSERT INTO wallet_transactions (
    agent_id,
    amount,
    type,
    status,
    notes,
    admin_id,
    completed_at
  ) VALUES (
    p_agent_id,
    p_amount,
    'deposit',
    'completed',
    p_notes,
    auth.uid(),
    NOW()
  ) RETURNING id INTO v_transaction_id;
  
  -- Update agent balance
  UPDATE agents
  SET current_balance = current_balance + p_amount
  WHERE user_id = p_agent_id;
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'transaction_id', v_transaction_id,
    'message', 'Funds added successfully'
  );
END;
$$;

-- Function for admin to subtract funds from agent wallet
CREATE OR REPLACE FUNCTION admin_subtract_agent_funds(
  p_agent_id UUID,
  p_amount NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_is_agent BOOLEAN;
  v_current_balance NUMERIC;
  v_transaction_id UUID;
BEGIN
  -- Check if user is admin
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) INTO v_is_admin;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Only admins can subtract funds from agent wallets'
    );
  END IF;
  
  -- Check if agent exists and get current balance
  SELECT current_balance INTO v_current_balance
  FROM agents
  WHERE user_id = p_agent_id;
  
  IF v_current_balance IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Agent not found'
    );
  END IF;
  
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Amount must be greater than zero'
    );
  END IF;
  
  -- Check if agent has enough balance
  IF v_current_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Insufficient balance'
    );
  END IF;
  
  -- Create transaction record
  INSERT INTO wallet_transactions (
    agent_id,
    amount,
    type,
    status,
    notes,
    admin_id,
    completed_at
  ) VALUES (
    p_agent_id,
    p_amount,
    'withdrawal',
    'completed',
    p_notes,
    auth.uid(),
    NOW()
  ) RETURNING id INTO v_transaction_id;
  
  -- Update agent balance
  UPDATE agents
  SET current_balance = current_balance - p_amount
  WHERE user_id = p_agent_id;
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'transaction_id', v_transaction_id,
    'message', 'Funds subtracted successfully'
  );
END;
$$;

-- Function for agent to request withdrawal
CREATE OR REPLACE FUNCTION agent_request_withdrawal(
  p_amount NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent BOOLEAN;
  v_current_balance NUMERIC;
  v_transaction_id UUID;
BEGIN
  -- Check if user is an agent
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = auth.uid()
  ) INTO v_is_agent;
  
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Only agents can request withdrawals'
    );
  END IF;
  
  -- Get current balance
  SELECT current_balance INTO v_current_balance
  FROM agents
  WHERE user_id = auth.uid();
  
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Amount must be greater than zero'
    );
  END IF;
  
  -- Check if agent has enough balance
  IF v_current_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Insufficient balance'
    );
  END IF;
  
  -- Create transaction record
  INSERT INTO wallet_transactions (
    agent_id,
    amount,
    type,
    status,
    notes
  ) VALUES (
    auth.uid(),
    p_amount,
    'withdrawal',
    'pending',
    p_notes
  ) RETURNING id INTO v_transaction_id;
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'transaction_id', v_transaction_id,
    'message', 'Withdrawal request submitted successfully'
  );
END;
$$;

-- Function for admin to process withdrawal request
CREATE OR REPLACE FUNCTION admin_process_withdrawal(
  p_transaction_id UUID,
  p_approve BOOLEAN,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_transaction RECORD;
  v_new_status TEXT;
BEGIN
  -- Check if user is admin
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) INTO v_is_admin;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Only admins can process withdrawal requests'
    );
  END IF;
  
  -- Get transaction details
  SELECT * INTO v_transaction
  FROM wallet_transactions
  WHERE id = p_transaction_id AND type = 'withdrawal' AND status = 'pending';
  
  IF v_transaction IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Withdrawal request not found or already processed'
    );
  END IF;
  
  -- Set new status based on approval
  IF p_approve THEN
    v_new_status := 'completed';
    
    -- Update agent balance
    UPDATE agents
    SET current_balance = current_balance - v_transaction.amount
    WHERE user_id = v_transaction.agent_id;
  ELSE
    v_new_status := 'rejected';
  END IF;
  
  -- Update transaction
  UPDATE wallet_transactions
  SET 
    status = v_new_status,
    notes = CASE WHEN p_notes IS NOT NULL THEN p_notes ELSE notes END,
    admin_id = auth.uid(),
    completed_at = CASE WHEN p_approve THEN NOW() ELSE NULL END,
    updated_at = NOW()
  WHERE id = p_transaction_id;
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'status', v_new_status,
    'message', 'Withdrawal request ' || 
      CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END || 
      ' successfully'
  );
END;
$$;

-- Function to get agent wallet transactions
CREATE OR REPLACE FUNCTION get_agent_wallet_transactions(
  p_agent_id UUID,
  p_limit INTEGER DEFAULT 10,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  amount NUMERIC,
  type TEXT,
  status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  reference_id UUID,
  admin_username TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is admin or the agent themselves
  IF NOT (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') OR
    auth.uid() = p_agent_id
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  
  RETURN QUERY
  SELECT 
    wt.id,
    wt.amount,
    wt.type,
    wt.status,
    wt.notes,
    wt.created_at,
    wt.completed_at,
    wt.reference_id,
    up.username as admin_username
  FROM wallet_transactions wt
  LEFT JOIN user_profiles up ON up.id = wt.admin_id
  WHERE wt.agent_id = p_agent_id
  ORDER BY wt.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Function to get agent wallet summary
CREATE OR REPLACE FUNCTION get_agent_wallet_summary(p_agent_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance NUMERIC;
  v_total_earnings NUMERIC;
  v_pending_withdrawals NUMERIC;
  v_completed_withdrawals NUMERIC;
  v_last_transaction RECORD;
BEGIN
  -- Check if user is admin or the agent themselves
  IF NOT (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') OR
    auth.uid() = p_agent_id
  ) THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Permission denied'
    );
  END IF;
  
  -- Get agent balance and earnings
  SELECT 
    current_balance,
    total_earnings
  INTO 
    v_current_balance,
    v_total_earnings
  FROM agents
  WHERE user_id = p_agent_id;
  
  IF v_current_balance IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Agent not found'
    );
  END IF;
  
  -- Get pending withdrawals
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM wallet_transactions
  WHERE agent_id = p_agent_id
  AND type = 'withdrawal'
  AND status = 'pending';
  
  -- Get completed withdrawals
  SELECT COALESCE(SUM(amount), 0) INTO v_completed_withdrawals
  FROM wallet_transactions
  WHERE agent_id = p_agent_id
  AND type = 'withdrawal'
  AND status = 'completed';
  
  -- Get last transaction
  SELECT 
    id,
    amount,
    type,
    status,
    created_at
  INTO v_last_transaction
  FROM wallet_transactions
  WHERE agent_id = p_agent_id
  ORDER BY created_at DESC
  LIMIT 1;
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'current_balance', v_current_balance,
    'total_earnings', v_total_earnings,
    'pending_withdrawals', v_pending_withdrawals,
    'completed_withdrawals', v_completed_withdrawals,
    'last_transaction', CASE 
      WHEN v_last_transaction IS NULL THEN NULL
      ELSE jsonb_build_object(
        'id', v_last_transaction.id,
        'amount', v_last_transaction.amount,
        'type', v_last_transaction.type,
        'status', v_last_transaction.status,
        'created_at', v_last_transaction.created_at
      )
    END
  );
END;
$$;

-- Update process_agent_commission function to record commission transactions
CREATE OR REPLACE FUNCTION process_agent_commission()
RETURNS TRIGGER AS $$
DECLARE
  order_user_id UUID;
  agent_user_id UUID;
  parent_agent_id UUID;
  order_total DECIMAL;
  agent_commission_rate DECIMAL;
  parent_commission_rate DECIMAL;
  agent_commission DECIMAL;
  parent_commission DECIMAL;
  referrer_id UUID;
  v_transaction_id UUID;
  v_parent_transaction_id UUID;
BEGIN
  -- Only process if order status changed to 'delivered'
  IF NEW.status = 'delivered' AND OLD.status <> 'delivered' THEN
    -- Get order user and total
    SELECT user_id, total INTO order_user_id, order_total FROM orders WHERE id = NEW.id;
    
    -- First check if the user has a referrer (direct referral relationship)
    SELECT referrer_id INTO referrer_id
    FROM user_profiles
    WHERE id = order_user_id;
    
    -- If user has a referrer, create commission for the referrer
    IF referrer_id IS NOT NULL THEN
      -- Get the referrer's commission rate
      SELECT commission_rate INTO agent_commission_rate
      FROM agents
      WHERE user_id = referrer_id;
      
      -- If referrer is an agent, calculate commission
      IF agent_commission_rate IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (referrer_id, NEW.id, agent_commission, 'pending');
        
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
          referrer_id,
          agent_commission,
          'commission',
          'completed',
          NEW.id,
          'Commission from order #' || (SELECT order_number FROM orders WHERE id = NEW.id),
          NOW()
        ) RETURNING id INTO v_transaction_id;
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = referrer_id;
        
        -- Get parent agent if exists
        SELECT parent_agent_id INTO parent_agent_id
        FROM agents
        WHERE user_id = referrer_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, NEW.id, parent_commission, 'pending');
          
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
            parent_agent_id,
            parent_commission,
            'commission',
            'completed',
            NEW.id,
            'Team commission from order #' || (SELECT order_number FROM orders WHERE id = NEW.id),
            NOW()
          ) RETURNING id INTO v_parent_transaction_id;
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    ELSE
      -- Find the agent associated with this user (through parent_agent_id)
      SELECT a.user_id, a.parent_agent_id, a.commission_rate 
      INTO agent_user_id, parent_agent_id, agent_commission_rate
      FROM user_profiles up
      LEFT JOIN agents a ON a.user_id = up.id
      WHERE up.id = order_user_id;
      
      -- If the user is associated with an agent
      IF agent_user_id IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (agent_user_id, NEW.id, agent_commission, 'pending');
        
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
          agent_user_id,
          agent_commission,
          'commission',
          'completed',
          NEW.id,
          'Commission from order #' || (SELECT order_number FROM orders WHERE id = NEW.id),
          NOW()
        ) RETURNING id INTO v_transaction_id;
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = agent_user_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, NEW.id, parent_commission, 'pending');
          
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
            parent_agent_id,
            parent_commission,
            'commission',
            'completed',
            NEW.id,
            'Team commission from order #' || (SELECT order_number FROM orders WHERE id = NEW.id),
            NOW()
          ) RETURNING id INTO v_parent_transaction_id;
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update handle_shared_order_payment_completion to record wallet transactions
CREATE OR REPLACE FUNCTION handle_shared_order_payment_completion()
RETURNS TRIGGER AS $$
DECLARE
  order_id UUID;
  order_user_id UUID;
  referrer_id UUID;
  agent_commission_rate DECIMAL;
  parent_agent_id UUID;
  parent_commission_rate DECIMAL;
  order_total DECIMAL;
  agent_commission DECIMAL;
  parent_commission DECIMAL;
  v_transaction_id UUID;
  v_parent_transaction_id UUID;
BEGIN
  -- Only process if shared order status changed to 'completed'
  IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
    -- Get the order ID
    order_id := NEW.order_id;
    
    -- Get order details
    SELECT user_id, total INTO order_user_id, order_total
    FROM orders
    WHERE id = order_id;
    
    -- Check if the user has a referrer
    SELECT referrer_id INTO referrer_id
    FROM user_profiles
    WHERE id = order_user_id;
    
    -- If user has a referrer, create commission for the referrer
    IF referrer_id IS NOT NULL THEN
      -- Get the referrer's commission rate and parent
      SELECT commission_rate, parent_agent_id INTO agent_commission_rate, parent_agent_id
      FROM agents
      WHERE user_id = referrer_id;
      
      -- If referrer is an agent, calculate commission
      IF agent_commission_rate IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (referrer_id, order_id, agent_commission, 'pending');
        
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
          referrer_id,
          agent_commission,
          'commission',
          'completed',
          order_id,
          'Commission from shared order #' || (SELECT order_number FROM orders WHERE id = order_id),
          NOW()
        ) RETURNING id INTO v_transaction_id;
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = referrer_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, order_id, parent_commission, 'pending');
          
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
            parent_agent_id,
            parent_commission,
            'commission',
            'completed',
            order_id,
            'Team commission from shared order #' || (SELECT order_number FROM orders WHERE id = order_id),
            NOW()
          ) RETURNING id INTO v_parent_transaction_id;
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    END IF;
    
    -- Update the order status to processing if it's still pending
    UPDATE orders
    SET 
      status = CASE WHEN status = 'pending' THEN 'processing' ELSE status END,
      payment_status = 'completed'
    WHERE id = order_id
    AND payment_status = 'pending';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION admin_add_agent_funds(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_subtract_agent_funds(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION agent_request_withdrawal(NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_process_withdrawal(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_wallet_transactions(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_wallet_summary(UUID) TO authenticated;