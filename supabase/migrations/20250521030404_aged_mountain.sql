-- Drop the existing function first to avoid return type error
DROP FUNCTION IF EXISTS process_friend_payment(uuid, uuid);

-- Create new function with void return type
CREATE OR REPLACE FUNCTION process_friend_payment(
  p_order_id UUID,
  p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_order_total NUMERIC(10,2);
BEGIN
  -- Get the referrer_id from user_profiles for the order's user
  SELECT up.referrer_id INTO v_referrer_id
  FROM orders o
  JOIN user_profiles up ON up.id = o.user_id
  WHERE o.id = p_order_id;

  -- Get order total
  SELECT total INTO v_order_total
  FROM orders
  WHERE id = p_order_id;

  -- If there's a referrer, create agent commission
  IF v_referrer_id IS NOT NULL THEN
    -- Check if referrer is an agent
    IF EXISTS (
      SELECT 1 FROM agents WHERE user_id = v_referrer_id
    ) THEN
      -- Calculate commission (5% of order total)
      INSERT INTO commissions (
        agent_id,
        order_id,
        amount,
        status
      )
      VALUES (
        v_referrer_id,
        p_order_id,
        v_order_total * 0.05,
        'pending'
      );
    END IF;
  END IF;

  -- Update order status
  UPDATE orders
  SET 
    status = 'processing',
    payment_status = 'completed'
  WHERE id = p_order_id;

  -- Update shared order status
  UPDATE shared_orders
  SET status = 'completed'
  WHERE order_id = p_order_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION process_friend_payment(uuid, uuid) TO authenticated;