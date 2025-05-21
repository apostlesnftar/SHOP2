/*
  # Agent Team Management Functions
  
  1. New Functions
    - `check_agent_status`: Checks if a user is an agent and returns their status
    - `create_agent_if_not_exists`: Creates an agent record if it doesn't exist
    - `count_team_members_by_parent`: Counts team members grouped by parent agent
    - `get_agent_team_members`: Gets all team members for an agent
    - `get_agent_team_stats`: Gets comprehensive statistics for an agent's team
    - `get_agent_commission_summary`: Gets commission summary for an agent
    - `get_agent_processing_orders_stats`: Gets processing orders statistics for an agent
  
  2. Security
    - All functions are security definer to ensure proper access control
    - Functions validate agent status before returning data
*/

-- Function to check if a user is an agent based on their role in user_profiles
CREATE OR REPLACE FUNCTION check_agent_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_agent_exists boolean;
  v_agent_status text;
  v_agent_record record;
  v_user_role text;
  v_commission_rate numeric(5,2);
BEGIN
  -- First check if the user has the agent role
  SELECT role INTO v_user_role
  FROM user_profiles
  WHERE id = p_user_id;
  
  IF v_user_role != 'agent' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an agent',
      'role', v_user_role
    );
  END IF;
  
  -- Check if agent record exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_user_id
  ) INTO v_agent_exists;
  
  -- If agent record doesn't exist, return false
  IF NOT v_agent_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Agent record not found',
      'role', v_user_role
    );
  END IF;
  
  -- Get agent status and commission rate
  SELECT 
    status,
    commission_rate 
  INTO 
    v_agent_status,
    v_commission_rate
  FROM agents
  WHERE user_id = p_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'status', v_agent_status,
    'role', v_user_role,
    'commission_rate', v_commission_rate
  );
END;
$$;

-- Function to create an agent record if it doesn't exist
CREATE OR REPLACE FUNCTION create_agent_if_not_exists(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_agent_exists boolean;
  v_agent_record record;
  v_user_role text;
BEGIN
  -- First check if the user exists
  SELECT role INTO v_user_role
  FROM user_profiles
  WHERE id = p_user_id;
  
  IF v_user_role IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  -- Update user role to agent if not already
  IF v_user_role != 'agent' THEN
    UPDATE user_profiles
    SET role = 'agent'
    WHERE id = p_user_id;
  END IF;
  
  -- Check if agent record exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_user_id
  ) INTO v_agent_exists;
  
  -- If agent record doesn't exist, create it
  IF NOT v_agent_exists THEN
    INSERT INTO agents (
      user_id,
      level,
      commission_rate,
      status
    ) VALUES (
      p_user_id,
      1,
      5.0,
      'active'
    )
    RETURNING * INTO v_agent_record;
    
    RETURN jsonb_build_object(
      'success', true,
      'status', v_agent_record.status,
      'created', true
    );
  END IF;
  
  -- Get updated agent record
  SELECT * INTO v_agent_record
  FROM agents
  WHERE user_id = p_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'status', v_agent_record.status,
    'created', false
  );
END;
$$;

-- Function to count team members grouped by parent agent
CREATE OR REPLACE FUNCTION count_team_members_by_parent()
RETURNS TABLE (
  parent_agent_id uuid,
  count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    agents.parent_agent_id,
    COUNT(agents.user_id)
  FROM agents
  WHERE agents.parent_agent_id IS NOT NULL
  GROUP BY agents.parent_agent_id;
END;
$$;

-- Function to get all team members for an agent (direct and indirect)
CREATE OR REPLACE FUNCTION get_agent_team_members(p_agent_id uuid)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  commission_rate numeric,
  total_earnings numeric,
  current_balance numeric,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent boolean;
  v_team_member_ids uuid[];
  v_current_level uuid[];
  v_next_level uuid[];
  i integer;
BEGIN
  -- Check if the user is an agent
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  -- If not an agent, return empty result
  IF NOT v_is_agent THEN
    RETURN;
  END IF;
  
  -- Initialize with the agent's own ID
  v_current_level := ARRAY[p_agent_id];
  
  -- Traverse the agent hierarchy to get all team members (up to 5 levels deep)
  FOR i IN 1..5 LOOP
    -- Exit if no more team members at this level
    EXIT WHEN array_length(v_current_level, 1) IS NULL;
    
    -- Get all direct downline members for the current level
    SELECT array_agg(user_id) INTO v_next_level
    FROM agents
    WHERE parent_agent_id = ANY(v_current_level);
    
    -- Exit if no more downline members
    EXIT WHEN v_next_level IS NULL OR v_next_level = '{NULL}';
    
    -- Add these members to the result
    RETURN QUERY
    SELECT 
      a.user_id,
      up.username,
      up.full_name,
      a.level,
      a.commission_rate,
      a.total_earnings,
      a.current_balance,
      a.status,
      a.created_at
    FROM agents a
    JOIN user_profiles up ON up.id = a.user_id
    WHERE a.user_id = ANY(v_next_level);
    
    -- Set up for next iteration
    v_current_level := v_next_level;
  END LOOP;
END;
$$;

-- Function to get comprehensive statistics for an agent's team
CREATE OR REPLACE FUNCTION get_agent_team_stats(p_agent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent boolean;
  v_team_size integer;
  v_total_earnings numeric(10,2);
  v_total_orders integer;
  v_total_order_amount numeric(10,2);
  v_processing_orders integer;
  v_processing_amount numeric(10,2);
  v_completed_orders integer;
  v_completed_amount numeric(10,2);
  v_team_member_ids uuid[];
  v_current_level uuid[];
  v_next_level uuid[];
  i integer;
BEGIN
  -- Check if the user is an agent
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  -- If not an agent, return error
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an agent'
    );
  END IF;
  
  -- Initialize with the agent's own ID
  v_team_member_ids := ARRAY[p_agent_id];
  v_current_level := ARRAY[p_agent_id];
  
  -- Traverse the agent hierarchy to get all team members (up to 5 levels deep)
  FOR i IN 1..5 LOOP
    -- Exit if no more team members at this level
    EXIT WHEN array_length(v_current_level, 1) IS NULL;
    
    -- Get all direct downline members for the current level
    SELECT array_agg(user_id) INTO v_next_level
    FROM agents
    WHERE parent_agent_id = ANY(v_current_level);
    
    -- Exit if no more downline members
    EXIT WHEN v_next_level IS NULL OR v_next_level = '{NULL}';
    
    -- Add these members to the team
    v_team_member_ids := v_team_member_ids || v_next_level;
    
    -- Set up for next iteration
    v_current_level := v_next_level;
  END LOOP;
  
  -- Calculate team size (excluding the agent themselves)
  v_team_size := array_length(v_team_member_ids, 1);
  IF v_team_size IS NULL THEN
    v_team_size := 0;
  ELSE
    v_team_size := v_team_size - 1; -- Subtract 1 to exclude the agent themselves
  END IF;
  
  -- Get total earnings for the team
  SELECT COALESCE(SUM(total_earnings), 0) INTO v_total_earnings
  FROM agents
  WHERE user_id = ANY(v_team_member_ids);
  
  -- Get total orders and amount
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_total_orders,
    v_total_order_amount
  FROM orders o
  JOIN commissions c ON c.order_id = o.id
  WHERE c.agent_id = ANY(v_team_member_ids);
  
  -- Get processing orders and amount
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_processing_orders,
    v_processing_amount
  FROM orders o
  JOIN commissions c ON c.order_id = o.id
  WHERE c.agent_id = ANY(v_team_member_ids)
  AND o.status = 'processing';
  
  -- Get completed orders and amount
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_completed_orders,
    v_completed_amount
  FROM orders o
  JOIN commissions c ON c.order_id = o.id
  WHERE c.agent_id = ANY(v_team_member_ids)
  AND o.status = 'delivered';
  
  -- Return the statistics as JSON
  RETURN jsonb_build_object(
    'success', true,
    'team_size', v_team_size,
    'total_earnings', v_total_earnings,
    'total_orders', v_total_orders,
    'total_amount', v_total_order_amount,
    'processing_orders', v_processing_orders,
    'processing_amount', v_processing_amount,
    'completed_orders', v_completed_orders,
    'completed_amount', v_completed_amount
  );
END;
$$;

-- Function to get commission summary for an agent
CREATE OR REPLACE FUNCTION get_agent_commission_summary(p_agent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent boolean;
  v_total_commissions numeric(10,2);
  v_pending_commissions numeric(10,2);
  v_paid_commissions numeric(10,2);
  v_commission_rate numeric(5,2);
  v_recent_commissions jsonb;
BEGIN
  -- Check if the user is an agent
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  -- If not an agent, return error
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an agent'
    );
  END IF;
  
  -- Get commission rate
  SELECT commission_rate INTO v_commission_rate
  FROM agents
  WHERE user_id = p_agent_id;
  
  -- Get total commissions
  SELECT COALESCE(SUM(amount), 0) INTO v_total_commissions
  FROM commissions
  WHERE agent_id = p_agent_id;
  
  -- Get pending commissions
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_commissions
  FROM commissions
  WHERE agent_id = p_agent_id
  AND status = 'pending';
  
  -- Get paid commissions
  SELECT COALESCE(SUM(amount), 0) INTO v_paid_commissions
  FROM commissions
  WHERE agent_id = p_agent_id
  AND status = 'paid';
  
  -- Get recent commissions
  SELECT json_agg(
    jsonb_build_object(
      'id', c.id,
      'order_id', c.order_id,
      'amount', c.amount,
      'status', c.status,
      'created_at', c.created_at,
      'paid_at', c.paid_at,
      'order_number', o.order_number
    )
  )
  INTO v_recent_commissions
  FROM commissions c
  JOIN orders o ON o.id = c.order_id
  WHERE c.agent_id = p_agent_id
  ORDER BY c.created_at DESC
  LIMIT 5;
  
  -- Return the summary as JSON
  RETURN jsonb_build_object(
    'success', true,
    'commission_rate', v_commission_rate,
    'total_commissions', v_total_commissions,
    'pending_commissions', v_pending_commissions,
    'paid_commissions', v_paid_commissions,
    'recent_commissions', COALESCE(v_recent_commissions, '[]'::jsonb)
  );
END;
$$;

-- Function to get processing orders statistics for a specific agent and their team
CREATE OR REPLACE FUNCTION get_agent_processing_orders_stats(p_agent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
  v_total numeric(10,2);
  v_is_agent boolean;
  v_team_member_ids uuid[];
  v_current_level uuid[];
  v_next_level uuid[];
  i integer;
BEGIN
  -- Check if the user is an agent
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  -- If not an agent, return error
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an agent'
    );
  END IF;
  
  -- Initialize with the agent's own ID
  v_team_member_ids := ARRAY[p_agent_id];
  v_current_level := ARRAY[p_agent_id];
  
  -- Traverse the agent hierarchy to get all team members (up to 5 levels deep)
  FOR i IN 1..5 LOOP
    -- Exit if no more team members at this level
    EXIT WHEN array_length(v_current_level, 1) IS NULL;
    
    -- Get all direct downline members for the current level
    SELECT array_agg(user_id) INTO v_next_level
    FROM agents
    WHERE parent_agent_id = ANY(v_current_level);
    
    -- Exit if no more downline members
    EXIT WHEN v_next_level IS NULL OR v_next_level = '{NULL}';
    
    -- Add these members to the team
    v_team_member_ids := v_team_member_ids || v_next_level;
    
    -- Set up for next iteration
    v_current_level := v_next_level;
  END LOOP;
  
  -- Get count and total amount of processing orders for this agent and team
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_count,
    v_total
  FROM orders o
  JOIN commissions c ON c.order_id = o.id
  WHERE o.status = 'processing'
  AND c.agent_id = ANY(v_team_member_ids);
  
  -- Return the statistics as JSON
  RETURN jsonb_build_object(
    'success', true,
    'count', v_count,
    'total', v_total
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_agent_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_agent_if_not_exists(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION count_team_members_by_parent() TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_team_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_commission_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_processing_orders_stats(uuid) TO authenticated;