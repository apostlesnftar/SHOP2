/*
  # Fix ambiguous referrer_id reference in process_friend_payment function

  1. Changes
    - Update process_friend_payment function to properly qualify the referrer_id column
    - Add explicit table aliases to improve query readability
    - Ensure proper column references in joins

  2. Security
    - No changes to security policies
    - Function remains security definer to maintain existing permissions
*/

CREATE OR REPLACE FUNCTION process_friend_payment(
  p_order_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id uuid;
  v_order_total numeric(10,2);
BEGIN
  -- Get the order details and referrer_id with explicit table aliases
  SELECT o.total, up.referrer_id 
  INTO v_order_total, v_referrer_id
  FROM orders o
  JOIN user_profiles up ON up.id = o.user_id
  WHERE o.id = p_order_id;

  -- If there's no referrer, just mark the order as processing
  IF v_referrer_id IS NULL THEN
    UPDATE orders
    SET status = 'processing',
        payment_status = 'completed',
        updated_at = NOW()
    WHERE id = p_order_id;
    
    RETURN true;
  END IF;

  -- Process the order with referrer
  UPDATE orders
  SET status = 'processing',
      payment_status = 'completed',
      updated_at = NOW()
  WHERE id = p_order_id;

  -- Create commission for the referrer
  INSERT INTO commissions (
    agent_id,
    order_id,
    amount,
    status,
    created_at
  )
  SELECT 
    a.user_id,
    p_order_id,
    v_order_total * (a.commission_rate / 100),
    'pending',
    NOW()
  FROM agents a
  WHERE a.user_id = v_referrer_id
  AND a.status = 'active';

  RETURN true;
END;
$$;