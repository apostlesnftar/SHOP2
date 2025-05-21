/*
  # Add Processing Orders Statistics Functions
  
  1. New Functions
    - `get_processing_orders_stats` - Returns count and total amount of processing orders
    - `get_agent_processing_orders_stats` - Returns processing orders stats for a specific agent
  
  2. Security
    - Functions are accessible to authenticated users
    - Agent function validates the user is an agent
*/

-- Function to get processing orders statistics
CREATE OR REPLACE FUNCTION get_processing_orders_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
  v_total numeric(10,2);
BEGIN
  -- Get count and total amount of processing orders
  SELECT 
    COUNT(*),
    COALESCE(SUM(total), 0)
  INTO 
    v_count,
    v_total
  FROM orders
  WHERE status = 'processing';
  
  -- Return the statistics as JSON
  RETURN jsonb_build_object(
    'count', v_count,
    'total', v_total
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
  
  -- Get count and total amount of processing orders for this agent
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_count,
    v_total
  FROM orders o
  JOIN commissions c ON c.order_id = o.id
  WHERE o.status = 'processing'
  AND c.agent_id = p_agent_id;
  
  -- Return the statistics as JSON
  RETURN jsonb_build_object(
    'success', true,
    'count', v_count,
    'total', v_total
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_processing_orders_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_processing_orders_stats(uuid) TO authenticated;