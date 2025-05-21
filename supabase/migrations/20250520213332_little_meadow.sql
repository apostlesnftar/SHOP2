/*
  # Fix Ambiguous Column Reference in get_agent_wallet_transactions
  
  1. Changes
    - Update get_agent_wallet_transactions function to explicitly specify table aliases for all columns
    - Fix the "column reference 'id' is ambiguous" error
    - Ensure proper column selection from wallet_transactions table
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control
*/

-- Function to get wallet transactions for a specific agent with pagination
CREATE OR REPLACE FUNCTION get_agent_wallet_transactions(
  p_agent_id UUID,
  p_limit INTEGER DEFAULT 10,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  amount NUMERIC,
  type TEXT,
  status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  reference_id UUID,
  admin_username TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is admin or the agent themselves
  IF NOT (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') OR
    auth.uid() = p_agent_id
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  
  RETURN QUERY
  SELECT 
    wt.id,
    wt.amount,
    wt.type,
    wt.status,
    wt.notes,
    wt.created_at,
    wt.completed_at,
    wt.reference_id,
    up.username as admin_username
  FROM wallet_transactions wt
  LEFT JOIN user_profiles up ON up.id = wt.admin_id
  WHERE wt.agent_id = p_agent_id
  ORDER BY wt.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agent_wallet_transactions(UUID, INTEGER, INTEGER) TO authenticated;