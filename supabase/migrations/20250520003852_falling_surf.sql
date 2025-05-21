/*
  # Agent Team Order Statistics
  
  1. New Functions
    - get_agent_team_order_stats - Get order statistics for an agent and their entire team
    - get_agent_processing_orders_stats - Get processing orders statistics for an agent
  
  2. Security
    - Functions are accessible to authenticated users
    - Proper validation of agent status
    - Comprehensive team hierarchy traversal
*/

-- Function to get order statistics for an agent and their entire team (including nested levels)
CREATE OR REPLACE FUNCTION get_agent_team_order_stats(p_agent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent boolean;
  v_total_orders integer := 0;
  v_total_amount numeric(10,2) := 0;
  v_processing_orders integer := 0;
  v_processing_amount numeric(10,2) := 0;
  v_completed_orders integer := 0;
  v_completed_amount numeric(10,2) := 0;
  v_team_member_ids uuid[];
  v_temp_ids uuid[];
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
    EXIT WHEN v_next_level IS NULL;
    
    -- Add these members to the team
    v_team_member_ids := v_team_member_ids || v_next_level;
    
    -- Set up for next iteration
    v_current_level := v_next_level;
  END LOOP;
  
  -- Get total orders and amount
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_total_orders,
    v_total_amount
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
    'total_orders', v_total_orders,
    'total_amount', v_total_amount,
    'processing_orders', v_processing_orders,
    'processing_amount', v_processing_amount,
    'completed_orders', v_completed_orders,
    'completed_amount', v_completed_amount,
    'team_size', array_length(v_team_member_ids, 1) - 1 -- Subtract 1 to exclude the agent themselves
  );
END;
$$;

-- Function to get processing orders statistics for a specific agent
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
    EXIT WHEN v_next_level IS NULL;
    
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
GRANT EXECUTE ON FUNCTION get_agent_team_order_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_processing_orders_stats(uuid) TO authenticated;