/*
  # Fix Agent Team Loading
  
  1. Changes
    - Update get_agent_team_members function to properly fetch direct team members
    - Add function to get team members for dashboard display
    - Fix issue with team members not showing in agent dashboard
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control
*/

-- Fix get_agent_team_members function to properly fetch direct team members
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
BEGIN
  -- Return direct team members (where parent_agent_id = p_agent_id)
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
  WHERE a.parent_agent_id = p_agent_id;
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
  total_earnings numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return direct team members (where parent_agent_id = p_agent_id)
  RETURN QUERY
  SELECT 
    a.user_id,
    up.username,
    up.full_name,
    a.level,
    a.status,
    a.created_at,
    a.total_earnings
  FROM agents a
  JOIN user_profiles up ON up.id = a.user_id
  WHERE a.parent_agent_id = p_agent_id
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Function to count team members by parent agent
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
    a.parent_agent_id,
    COUNT(a.user_id)::bigint
  FROM agents a
  WHERE a.parent_agent_id IS NOT NULL
  GROUP BY a.parent_agent_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION count_team_members_by_parent() TO authenticated;