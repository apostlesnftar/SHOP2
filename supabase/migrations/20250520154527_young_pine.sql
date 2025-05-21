/*
  # Fix Agent Team Loading
  
  1. Changes
    - Add function to get team members based on both parent_agent_id and referrer_id
    - Update existing team member functions to include users referred through user_profiles.referrer_id
    - Improve team member counting to include all types of referrals
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control for team member data
*/

-- Improved function to get agent team members including those referred via referrer_id
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
  WHERE a.parent_agent_id = p_agent_id
  
  UNION
  
  -- Also include users who were referred via user_profiles.referrer_id
  -- but might not have parent_agent_id set
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
  WHERE up.referrer_id = p_agent_id
  AND (a.parent_agent_id IS NULL OR a.parent_agent_id != p_agent_id);
END;
$$;

-- Improved function to get team members for dashboard display
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
  -- Return team members from both parent_agent_id and referrer_id relationships
  RETURN QUERY
  (
    -- Get team members via parent_agent_id
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
    
    UNION
    
    -- Get team members via referrer_id
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
    WHERE up.referrer_id = p_agent_id
    AND (a.parent_agent_id IS NULL OR a.parent_agent_id != p_agent_id)
  )
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$;

-- Improved function to count team members by parent agent
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
    parent_id,
    COUNT(user_id)::bigint
  FROM (
    -- Count team members via parent_agent_id
    SELECT 
      a.parent_agent_id as parent_id,
      a.user_id
    FROM agents a
    WHERE a.parent_agent_id IS NOT NULL
    
    UNION
    
    -- Count team members via referrer_id
    SELECT 
      up.referrer_id as parent_id,
      a.user_id
    FROM agents a
    JOIN user_profiles up ON up.id = a.user_id
    WHERE up.referrer_id IS NOT NULL
    AND (a.parent_agent_id IS NULL OR a.parent_agent_id != up.referrer_id)
  ) as combined_team
  GROUP BY parent_id;
END;
$$;

-- Function to sync parent_agent_id with referrer_id to ensure consistency
CREATE OR REPLACE FUNCTION sync_agent_relationships()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update agents where referrer_id exists but parent_agent_id doesn't match
  UPDATE agents a
  SET parent_agent_id = up.referrer_id
  FROM user_profiles up
  WHERE a.user_id = up.id
  AND up.referrer_id IS NOT NULL
  AND (a.parent_agent_id IS NULL OR a.parent_agent_id != up.referrer_id);
  
  -- Update user_profiles where parent_agent_id exists but referrer_id doesn't match
  UPDATE user_profiles up
  SET referrer_id = a.parent_agent_id
  FROM agents a
  WHERE up.id = a.user_id
  AND a.parent_agent_id IS NOT NULL
  AND (up.referrer_id IS NULL OR up.referrer_id != a.parent_agent_id);
END;
$$;

-- Run the sync function to fix existing data
SELECT sync_agent_relationships();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION count_team_members_by_parent() TO authenticated;
GRANT EXECUTE ON FUNCTION sync_agent_relationships() TO authenticated;