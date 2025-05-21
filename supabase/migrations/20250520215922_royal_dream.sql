/*
  # Fix ambiguous referrer_id reference

  1. Changes
    - Update process_friend_payment function to properly qualify referrer_id column
    - Add explicit table aliases to improve query readability
    - Add better error handling for payment processing
*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS process_friend_payment(p_share_id text, p_payment_method text);

-- Recreate the function with fixed column references
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
  v_order_total numeric(10,2);
  v_commission_rate numeric(5,2);
  v_commission_amount numeric(10,2);
BEGIN
  -- Get order details and user info
  SELECT 
    o.id,
    o.user_id,
    o.total,
    up.referrer_id
  INTO 
    v_order_id,
    v_user_id,
    v_order_total,
    v_referrer_id
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  JOIN user_profiles up ON up.id = o.user_id
  WHERE so.share_id = p_share_id
    AND so.status = 'pending'
    AND o.payment_status = 'pending';

  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired share ID'
    );
  END IF;

  -- Begin transaction
  BEGIN
    -- Update order status and payment method
    UPDATE orders
    SET 
      payment_method = p_payment_method,
      status = 'processing',
      payment_status = 'completed',
      updated_at = NOW()
    WHERE id = v_order_id;

    -- Update shared order status
    UPDATE shared_orders
    SET 
      status = 'completed',
      updated_at = NOW()
    WHERE share_id = p_share_id;

    -- If there's a referrer, calculate and record commission
    IF v_referrer_id IS NOT NULL THEN
      -- Get the agent's commission rate
      SELECT commission_rate 
      INTO v_commission_rate
      FROM agents 
      WHERE user_id = v_referrer_id;

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

        -- Update agent's current balance and total earnings
        UPDATE agents
        SET 
          current_balance = current_balance + v_commission_amount,
          total_earnings = total_earnings + v_commission_amount
        WHERE user_id = v_referrer_id;
      END IF;
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Roll back transaction on error
      RAISE LOG 'Error in process_friend_payment: %', SQLERRM;
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;