/*
  # Add Agent Team Order Statistics Functions
  
  1. New Functions
    - get_agent_team_order_stats - Get order statistics for an agent and their team
    - This function calculates total orders, processing orders, and completed orders
    - Includes both direct commissions and team member commissions
  
  2. Security
    - Function is accessible to authenticated users
    - Proper validation of agent existence
*/

-- Function to get order statistics for an agent and their team
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
  
  -- Get all team member IDs (direct downline)
  SELECT array_agg(user_id) INTO v_team_member_ids
  FROM agents
  WHERE parent_agent_id = p_agent_id;
  
  -- If no team members, use empty array
  IF v_team_member_ids IS NULL THEN
    v_team_member_ids := ARRAY[]::uuid[];
  END IF;
  
  -- Add the agent's own ID to the array
  v_team_member_ids := array_append(v_team_member_ids, p_agent_id);
  
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agent_team_order_stats(uuid) TO authenticated;