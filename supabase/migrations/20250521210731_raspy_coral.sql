/*
  # Update Friend Payment Processing

  1. Changes
    - Add proper referrer handling for order creators
    - Support anonymous users in payment processing
    - Update wallet commissions for referrers
    - Fix order status updates
    
  2. Security
    - Maintain RLS policies
    - Add proper error handling
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS process_friend_payment(p_share_id text, p_payment_method text);

-- Create updated function with proper referrer handling
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
  v_referrer_id uuid;
  v_commission_rate numeric;
  v_order_total numeric;
  v_commission_amount numeric;
BEGIN
  -- Get order details from shared_orders
  SELECT order_id INTO v_order_id
  FROM shared_orders
  WHERE share_id = p_share_id
    AND status = 'pending'
    AND expires_at > now();

  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired share ID'
    );
  END IF;

  -- Get order creator and total
  SELECT o.user_id, o.total, up.referrer_id
  INTO v_user_id, v_order_total, v_referrer_id
  FROM orders o
  LEFT JOIN user_profiles up ON up.id = o.user_id
  WHERE o.id = v_order_id;

  -- Process commission if there's a referrer
  IF v_referrer_id IS NOT NULL THEN
    -- Get referrer's commission rate
    SELECT commission_rate INTO v_commission_rate
    FROM agents
    WHERE user_id = v_referrer_id
      AND status = 'active';

    IF v_commission_rate IS NOT NULL THEN
      -- Calculate commission amount
      v_commission_amount := (v_order_total * v_commission_rate / 100)::numeric(10,2);

      -- Create commission record
      INSERT INTO commissions (
        agent_id,
        order_id,
        amount,
        status
      ) VALUES (
        v_referrer_id,
        v_order_id,
        v_commission_amount,
        'pending'
      );

      -- Update agent's earnings and balance
      UPDATE agents
      SET total_earnings = total_earnings + v_commission_amount,
          current_balance = current_balance + v_commission_amount
      WHERE user_id = v_referrer_id;
    END IF;
  END IF;

  -- Update order status
  UPDATE orders
  SET status = 'processing',
      payment_status = 'completed',
      payment_method = p_payment_method
  WHERE id = v_order_id;

  -- Update shared order status
  UPDATE shared_orders
  SET status = 'completed'
  WHERE share_id = p_share_id;

  -- Return success response
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