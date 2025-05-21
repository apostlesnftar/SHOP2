-- Drop existing function first to avoid return type error
DROP FUNCTION IF EXISTS get_agent_commission_summary(uuid);

-- Recreate the function with JSONB return type and proper aggregation
CREATE OR REPLACE FUNCTION get_agent_commission_summary(p_agent_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_commission_rate NUMERIC;
  v_total_commissions NUMERIC;
  v_pending_commissions NUMERIC;
  v_paid_commissions NUMERIC;
  v_recent_commissions JSONB;
BEGIN
  -- Get agent's commission rate
  SELECT commission_rate INTO v_commission_rate
  FROM agents
  WHERE user_id = p_agent_id;

  -- Get commission totals
  SELECT
    COALESCE(SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(amount), 0)
  INTO v_pending_commissions, v_paid_commissions, v_total_commissions
  FROM commissions
  WHERE agent_id = p_agent_id;

  -- Get recent commissions with proper aggregation
  WITH recent_commissions AS (
    SELECT
      c.id,
      c.order_id,
      o.order_number,
      c.amount,
      c.status,
      c.created_at,
      c.paid_at
    FROM commissions c
    JOIN orders o ON o.id = c.order_id
    WHERE c.agent_id = p_agent_id
    ORDER BY c.created_at DESC
    LIMIT 10
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id,
      'orderId', order_id,
      'orderNumber', order_number,
      'amount', amount,
      'status', status,
      'createdAt', created_at,
      'paidAt', paid_at
    )
  ) INTO v_recent_commissions
  FROM recent_commissions;

  -- Return the result
  RETURN jsonb_build_object(
    'success', true,
    'commission_rate', v_commission_rate,
    'total_commissions', v_total_commissions,
    'pending_commissions', v_pending_commissions,
    'paid_commissions', v_paid_commissions,
    'recent_commissions', COALESCE(v_recent_commissions, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agent_commission_summary(uuid) TO authenticated;