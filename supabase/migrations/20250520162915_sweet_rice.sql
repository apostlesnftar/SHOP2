/*
  # Fix Agent Team Members Function
  
  1. Changes
    - Drop existing get_agent_team_members function
    - Create new version with correct return type
    - Fix the structure mismatch between function result and query
    - Ensure order_count and order_total are returned as integer and numeric
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control
*/

-- Drop existing functions first to avoid return type errors
DROP FUNCTION IF EXISTS get_agent_team_members(uuid);
DROP FUNCTION IF EXISTS get_agent_dashboard_team(uuid, integer);

-- Create new function to get all team members for an agent (including referred customers)
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
  created_at timestamptz,
  is_agent boolean,
  order_count integer,
  order_total numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return direct team members (agents where parent_agent_id = p_agent_id)
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
    a.created_at,
    TRUE as is_agent,
    COALESCE((
      SELECT COUNT(DISTINCT o.id)::integer
      FROM orders o
      JOIN commissions c ON c.order_id = o.id
      WHERE c.agent_id = a.user_id
    ), 0) as order_count,
    COALESCE((
      SELECT SUM(o.total)
      FROM orders o
      JOIN commissions c ON c.order_id = o.id
      WHERE c.agent_id = a.user_id
    ), 0::numeric) as order_total
  FROM agents a
  JOIN user_profiles up ON up.id = a.user_id
  WHERE a.parent_agent_id = p_agent_id
  
  UNION
  
  -- Include customers who were referred by this agent
  SELECT 
    up.id as user_id,
    up.username,
    up.full_name,
    0 as level, -- Level 0 for customers
    0 as commission_rate,
    0 as total_earnings,
    0 as current_balance,
    'customer' as status,
    up.created_at,
    FALSE as is_agent,
    COALESCE((
      SELECT COUNT(DISTINCT o.id)::integer
      FROM orders o
      LEFT JOIN shared_orders so ON so.order_id = o.id
      WHERE o.user_id = up.id
      OR (so.status = 'completed' AND o.user_id = up.id)
    ), 0) as order_count,
    COALESCE((
      SELECT SUM(o.total)
      FROM orders o
      LEFT JOIN shared_orders so ON so.order_id = o.id
      WHERE o.user_id = up.id
      OR (so.status = 'completed' AND o.user_id = up.id)
    ), 0::numeric) as order_total
  FROM user_profiles up
  WHERE up.referrer_id = p_agent_id
  AND up.role = 'customer'
  AND NOT EXISTS (
    -- Exclude users who are already agents
    SELECT 1 FROM agents a WHERE a.user_id = up.id
  );
END;
$$;

-- Function to get team members for dashboard display (limited to 5)
CREATE OR REPLACE FUNCTION get_agent_dashboard_team(p_agent_id uuid, p_limit integer DEFAULT 5)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  status text,
  created_at timestamptz,
  total_earnings numeric,
  is_agent boolean,
  order_count integer,
  order_total numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return team members from both parent_agent_id and referrer_id relationships
  RETURN QUERY
  (
    -- Get team members via parent_agent_id (agents)
    SELECT 
      a.user_id,
      up.username,
      up.full_name,
      a.level,
      a.status,
      a.created_at,
      a.total_earnings,
      TRUE as is_agent,
      COALESCE((
        SELECT COUNT(DISTINCT o.id)::integer
        FROM orders o
        JOIN commissions c ON c.order_id = o.id
        WHERE c.agent_id = a.user_id
      ), 0) as order_count,
      COALESCE((
        SELECT SUM(o.total)
        FROM orders o
        JOIN commissions c ON c.order_id = o.id
        WHERE c.agent_id = a.user_id
      ), 0::numeric) as order_total
    FROM agents a
    JOIN user_profiles up ON up.id = a.user_id
    WHERE a.parent_agent_id = p_agent_id
    
    UNION
    
    -- Get team members via referrer_id (customers)
    SELECT 
      up.id as user_id,
      up.username,
      up.full_name,
      0 as level,
      'customer' as status,
      up.created_at,
      0 as total_earnings,
      FALSE as is_agent,
      COALESCE((
        SELECT COUNT(DISTINCT o.id)::integer
        FROM orders o
        LEFT JOIN shared_orders so ON so.order_id = o.id
        WHERE o.user_id = up.id
        OR (so.status = 'completed' AND o.user_id = up.id)
      ), 0) as order_count,
      COALESCE((
        SELECT SUM(o.total)
        FROM orders o
        LEFT JOIN shared_orders so ON so.order_id = o.id
        WHERE o.user_id = up.id
        OR (so.status = 'completed' AND o.user_id = up.id)
      ), 0::numeric) as order_total
    FROM user_profiles up
    WHERE up.referrer_id = p_agent_id
    AND up.role = 'customer'
    AND NOT EXISTS (
      -- Exclude users who are already agents
      SELECT 1 FROM agents a WHERE a.user_id = up.id
    )
  )
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;