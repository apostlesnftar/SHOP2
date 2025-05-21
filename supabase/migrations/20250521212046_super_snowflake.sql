/*
  # Update shared order payment processing

  1. Changes
    - Update process_shared_order_payment function to:
      - Get original order creator's referrer
      - Process commission based on original order creator
      - Handle anonymous users without requiring referrer check
      - Update order status and process commissions correctly

  2. Security
    - Function is accessible to authenticated and anonymous users
    - Validates share ID and order existence
    - Ensures proper status transitions
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS process_shared_order_payment;

-- Create updated function
CREATE OR REPLACE FUNCTION process_shared_order_payment(
  p_share_id text,
  p_payment_method text,
  p_gateway_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order record;
  v_order_creator record;
  v_referrer_id uuid;
  v_commission_rate numeric;
  v_commission_amount numeric;
BEGIN
  -- Get shared order details
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or already processed'
    );
  END IF;

  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = v_shared_order.order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Get original order creator's profile
  SELECT up.* INTO v_order_creator
  FROM user_profiles up
  WHERE up.id = v_order.user_id;

  -- Get referrer ID from original order creator (if exists)
  v_referrer_id := v_order_creator.referrer_id;

  -- Update order status
  UPDATE orders
  SET 
    status = 'processing',
    payment_status = 'completed',
    payment_method = p_payment_method,
    updated_at = now()
  WHERE id = v_order.id;

  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = now()
  WHERE id = v_shared_order.id;

  -- Process commission if referrer exists
  IF v_referrer_id IS NOT NULL THEN
    -- Get commission rate from agents table
    SELECT commission_rate INTO v_commission_rate
    FROM agents
    WHERE user_id = v_referrer_id;

    IF FOUND THEN
      -- Calculate commission amount
      v_commission_amount := (v_order.total * v_commission_rate / 100);

      -- Create commission record
      INSERT INTO commissions (
        agent_id,
        order_id,
        amount,
        status
      ) VALUES (
        v_referrer_id,
        v_order.id,
        v_commission_amount,
        'pending'
      );

      -- Update agent earnings
      UPDATE agents
      SET 
        total_earnings = total_earnings + v_commission_amount,
        current_balance = current_balance + v_commission_amount,
        updated_at = now()
      WHERE user_id = v_referrer_id;
    END IF;
  END IF;

  -- Return success response
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'order_number', v_order.order_number
  );
END;
$$;