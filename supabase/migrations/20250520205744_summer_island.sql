-- Update get_agent_dashboard_team function to sort by created_at DESC
CREATE OR REPLACE FUNCTION get_agent_dashboard_team(p_agent_id uuid, p_limit integer DEFAULT 5)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  status text,
  created_at timestamptz,
  total_earnings numeric,
  is_agent boolean
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
      TRUE as is_agent
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
      FALSE as is_agent
    FROM user_profiles up
    WHERE up.referrer_id = p_agent_id
    AND up.role = 'customer'
    AND NOT EXISTS (
      -- Exclude users who are already agents
      SELECT 1 FROM agents a WHERE a.user_id = up.id
    )
  )
  ORDER BY created_at DESC  -- Explicitly sort by creation date, newest first
  LIMIT p_limit;
END;
$$;

-- Update get_agent_team_members function to include sorting by created_at DESC
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
  is_agent boolean
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return all team members sorted by creation date (newest first)
  RETURN QUERY
  (
    -- Direct team members (agents where parent_agent_id = p_agent_id)
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
      TRUE as is_agent
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
      FALSE as is_agent
    FROM user_profiles up
    WHERE up.referrer_id = p_agent_id
    AND up.role = 'customer'
    AND NOT EXISTS (
      -- Exclude users who are already agents
      SELECT 1 FROM agents a WHERE a.user_id = up.id
    )
  )
  ORDER BY created_at DESC;  -- Explicitly sort by creation date, newest first
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;