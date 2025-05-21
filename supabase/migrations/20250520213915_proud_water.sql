-- Drop existing function first to avoid conflicts
DROP FUNCTION IF EXISTS get_agent_wallet_transactions(uuid, integer, integer);

-- Recreate the function with fully qualified column references
CREATE OR REPLACE FUNCTION get_agent_wallet_transactions(
  p_agent_id UUID,
  p_limit INTEGER DEFAULT 10,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  transaction_id UUID,
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
    wt.id AS transaction_id,
    wt.amount,
    wt.type,
    wt.status,
    wt.notes,
    wt.created_at,
    wt.completed_at,
    wt.reference_id,
    up.username AS admin_username
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