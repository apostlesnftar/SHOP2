/*
  # Fix agent team members query

  1. Changes
    - Update get_agent_team_members function to fix ambiguous user_id reference
    - Explicitly specify table names for all column references
    - Add proper table aliases for better readability
    - Update return type to match the exact column names from tables

  2. Security
    - Maintain existing security context
    - Function remains accessible to authenticated users only
*/

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