/*
  # Agent Wallet Management Functions
  
  1. New Functions
    - `get_pending_withdrawals` - Get all pending withdrawal requests for admin dashboard
    - `get_agent_wallet_transactions` - Get wallet transactions for a specific agent
    - `get_agent_wallet_summary` - Get wallet summary for a specific agent
    - `admin_process_withdrawal` - Process a withdrawal request (approve/reject)
    - `admin_add_agent_funds` - Add funds to an agent's wallet
    - `admin_subtract_agent_funds` - Remove funds from an agent's wallet
    - `agent_request_withdrawal` - Allow an agent to request a withdrawal
  
  2. Security
    - Functions are accessible to authenticated users
    - Proper validation of agent and admin roles
    - Ensure proper access control for wallet operations
*/

-- Function to get all pending withdrawal requests for admin dashboard
CREATE OR REPLACE FUNCTION get_pending_withdrawals()
RETURNS TABLE (
  id UUID,
  agent_id UUID,
  agent_username TEXT,
  amount NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view pending withdrawals';
  END IF;
  
  RETURN QUERY
  SELECT 
    wt.id,
    wt.agent_id,
    up.username as agent_username,
    wt.amount,
    wt.notes,
    wt.created_at
  FROM wallet_transactions wt
  JOIN user_profiles up ON up.id = wt.agent_id
  WHERE wt.type = 'withdrawal'
  AND wt.status = 'pending'
  ORDER BY wt.created_at DESC;
END;
$$;

-- Function to get wallet transactions for a specific agent with pagination
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

-- Function to get wallet summary for a specific agent
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

-- Function for admin to process a withdrawal request
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

-- Function for admin to add funds to an agent's wallet
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

-- Function for admin to subtract funds from an agent's wallet
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
    'adjustment',
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

-- Function for agent to request a withdrawal
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_pending_withdrawals() TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_wallet_transactions(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_wallet_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_process_withdrawal(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_add_agent_funds(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_subtract_agent_funds(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION agent_request_withdrawal(NUMERIC, TEXT) TO authenticated;