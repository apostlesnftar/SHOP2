/*
  # Fix Agent Network Functions
  
  1. New Functions
    - get_agent_team_members - Get all team members for an agent
    - get_agent_team_stats - Get comprehensive statistics for an agent's team
    - get_agent_commission_summary - Get commission details for an agent
  
  2. Security
    - All functions use SECURITY DEFINER to ensure proper access control
    - Proper validation of agent status before returning data
*/

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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_team_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_commission_summary(uuid) TO authenticated;