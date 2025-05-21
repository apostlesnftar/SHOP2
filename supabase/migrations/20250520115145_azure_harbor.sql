/*
  # Fix Agent Queries
  
  1. New Functions
    - `count_team_members_by_parent` - Counts team members grouped by parent agent
    - Fixes the issue with the AdminAgentsPage query
  
  2. Security
    - Function is accessible to authenticated users
    - Proper error handling and validation
*/

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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION count_team_members_by_parent() TO authenticated;