/*
  # Fix ambiguous user_id reference in get_agent_team_members function
  
  1. Changes
    - Fix the ambiguous column reference "user_id" in the function
    - Use explicit table aliases for all column references
    - Ensure proper join conditions
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS get_agent_team_members(uuid);

-- Create a new version with explicit table aliases
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
  LEFT JOIN user_profiles up ON up.id = a.user_id
  WHERE a.parent_agent_id = p_agent_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;