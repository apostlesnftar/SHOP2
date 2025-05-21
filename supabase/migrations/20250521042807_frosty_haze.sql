-- Drop the existing function first to avoid return type error
DROP FUNCTION IF EXISTS process_friend_payment(p_share_id text, p_payment_method text);

-- Recreate the function with explicit table aliases and variable assignments
CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_total numeric(10,2);
  v_result jsonb;
BEGIN
  -- Get order details using table aliases
  SELECT 
    o.id,
    o.user_id,
    o.total
  INTO 
    v_order_id,
    v_user_id,
    v_total
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
    AND so.status = 'pending'
    AND so.expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired shared order'
    );
  END IF;

  -- Update order status using explicit table references
  UPDATE orders o
  SET 
    payment_method = p_payment_method,
    payment_status = 'completed',
    status = 'processing'
  WHERE o.id = v_order_id;

  -- Update shared order status
  UPDATE shared_orders so
  SET status = 'completed'
  WHERE so.share_id = p_share_id;

  -- Process referral if exists, using explicit table aliases
  UPDATE user_profiles up
  SET referrer_id = (
    SELECT up2.referrer_id 
    FROM user_profiles up2
    WHERE up2.id = v_user_id
  )
  WHERE up.id = v_user_id
    AND up.referrer_id IS NULL;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;