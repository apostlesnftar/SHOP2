/*
  # Fix Payment Success Handling
  
  1. Changes
    - Update process_friend_payment function to handle acacia_pay payment method
    - Add special handling for payment success redirect
    - Ensure order status is properly updated
    - Fix commission calculation for shared orders
*/

-- Drop the existing function if it exists
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
  v_order_total numeric;
  v_valid_payment_method boolean;
  v_so_referrer_id uuid; -- Explicitly named to avoid ambiguity
  v_so_order_number text; -- Explicitly named to avoid ambiguity
  v_agent_commission_rate numeric;
  v_agent_commission numeric;
  v_parent_agent_id uuid;
  v_parent_commission_rate numeric;
  v_parent_commission numeric;
  v_transaction_id uuid;
  v_parent_transaction_id uuid;
  v_payment_method_normalized text;
BEGIN
  -- Normalize payment method (lowercase and replace spaces with underscores)
  v_payment_method_normalized := LOWER(REPLACE(p_payment_method, ' ', '_'));
  
  -- Log the payment method for debugging
  RAISE LOG 'Processing payment with method: % (normalized: %)', p_payment_method, v_payment_method_normalized;
  
  -- Get shared order with explicit column selection and aliases to avoid ambiguity
  SELECT 
    so.order_id,
    so.referrer_id AS so_referrer_id, -- Explicitly aliased
    so.order_number AS so_order_number, -- Explicitly aliased
    o.user_id,
    o.total
  INTO 
    v_order_id,
    v_so_referrer_id,
    v_so_order_number,
    v_user_id,
    v_order_total
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE so.share_id = p_share_id
  AND so.expires_at > now()
  AND so.status = 'pending'
  AND o.payment_method = 'friend_payment'
  AND o.payment_status = 'pending';
  
  -- Validate shared order
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found, expired, or already paid'
    );
  END IF;
  
  -- Special handling for acacia_pay and test payment methods
  IF v_payment_method_normalized = 'acacia_pay' OR v_payment_method_normalized = 'test' THEN
    -- These payment methods are always valid
    v_valid_payment_method := true;
  ELSE
    -- Check if payment method is valid - USING CASE-INSENSITIVE COMPARISON
    SELECT EXISTS (
      SELECT 1 FROM (
        -- Get available payment methods from payment_gateways
        SELECT 
          LOWER(CASE 
            WHEN provider = 'stripe' THEN 'credit_card'
            WHEN provider = 'custom' THEN name
            ELSE provider
          END) as method
        FROM payment_gateways
        WHERE is_active = true
      ) methods
      WHERE methods.method = v_payment_method_normalized
    ) INTO v_valid_payment_method;
  END IF;
  
  -- Validate payment method
  IF NOT v_valid_payment_method THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method: ' || p_payment_method
    );
  END IF;
  
  -- If referrer_id is NULL in shared_orders, try to get it from user_profiles
  -- This is a fallback in case shared_orders.referrer_id is not set
  IF v_so_referrer_id IS NULL THEN
    SELECT up.referrer_id INTO v_so_referrer_id
    FROM user_profiles up
    WHERE up.id = v_user_id;
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing',
    payment_method = v_payment_method_normalized
  WHERE id = v_order_id
  AND payment_status = 'pending';
  
  -- Create audit log
  INSERT INTO order_audit_logs (
    order_id,
    user_id,
    old_status,
    new_status,
    old_payment_status,
    new_payment_status,
    notes
  ) VALUES (
    v_order_id,
    v_user_id,
    'pending',
    'processing',
    'pending',
    'completed',
    'Order payment completed via shared payment link using ' || p_payment_method
  );
  
  -- Update shared order status
  UPDATE shared_orders
  SET 
    status = 'completed',
    updated_at = now()
  WHERE share_id = p_share_id;
  
  -- If user has a referrer, create commission for the referrer
  IF v_so_referrer_id IS NOT NULL THEN
    -- Get the referrer's commission rate and parent
    SELECT a.commission_rate, a.parent_agent_id 
    INTO v_agent_commission_rate, v_parent_agent_id
    FROM agents a
    WHERE a.user_id = v_so_referrer_id;
    
    -- If referrer is an agent, calculate commission
    IF v_agent_commission_rate IS NOT NULL THEN
      -- Calculate commission
      v_agent_commission := (v_order_total * v_agent_commission_rate / 100);
      
      -- Create commission record
      INSERT INTO commissions (agent_id, order_id, amount, status)
      VALUES (v_so_referrer_id, v_order_id, v_agent_commission, 'pending');
      
      -- Create wallet transaction record
      INSERT INTO wallet_transactions (
        agent_id,
        amount,
        type,
        status,
        reference_id,
        notes,
        completed_at
      ) VALUES (
        v_so_referrer_id,
        v_agent_commission,
        'commission',
        'completed',
        v_order_id,
        'Commission from shared order #' || v_so_order_number,
        NOW()
      ) RETURNING id INTO v_transaction_id;
      
      -- Update agent total earnings and balance
      UPDATE agents
      SET total_earnings = total_earnings + v_agent_commission,
          current_balance = current_balance + v_agent_commission
      WHERE user_id = v_so_referrer_id;
      
      -- If there's a parent agent, calculate their commission too
      IF v_parent_agent_id IS NOT NULL THEN
        -- Get parent's commission rate
        SELECT a.commission_rate INTO v_parent_commission_rate
        FROM agents a 
        WHERE a.user_id = v_parent_agent_id;
        
        v_parent_commission := (v_order_total * v_parent_commission_rate / 200); -- Half the normal rate for the parent
        
        -- Create commission record for parent
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (v_parent_agent_id, v_order_id, v_parent_commission, 'pending');
        
        -- Create wallet transaction record for parent
        INSERT INTO wallet_transactions (
          agent_id,
          amount,
          type,
          status,
          reference_id,
          notes,
          completed_at
        ) VALUES (
          v_parent_agent_id,
          v_parent_commission,
          'commission',
          'completed',
          v_order_id,
          'Team commission from shared order #' || v_so_order_number,
          NOW()
        ) RETURNING id INTO v_parent_transaction_id;
        
        -- Update parent agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + v_parent_commission,
            current_balance = current_balance + v_parent_commission
        WHERE user_id = v_parent_agent_id;
      END IF;
    END IF;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_number', v_so_order_number
  );
END;
$$;

-- Create a function to handle payment success redirects
CREATE OR REPLACE FUNCTION handle_payment_success(
  p_order_number text,
  p_payment_method text DEFAULT 'acacia_pay'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_payment_status text;
  v_order_status text;
BEGIN
  -- Get order details
  SELECT 
    id, 
    user_id, 
    payment_status,
    status
  INTO 
    v_order_id,
    v_user_id,
    v_payment_status,
    v_order_status
  FROM orders
  WHERE order_number = p_order_number;
  
  -- Validate order
  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;
  
  -- If order is already paid, just return success
  IF v_payment_status = 'completed' THEN
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'order_number', p_order_number,
      'message', 'Order already paid'
    );
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = CASE WHEN status = 'pending' THEN 'processing' ELSE status END,
    payment_method = p_payment_method
  WHERE id = v_order_id;
  
  -- Create audit log
  INSERT INTO order_audit_logs (
    order_id,
    user_id,
    old_status,
    new_status,
    old_payment_status,
    new_payment_status,
    notes
  ) VALUES (
    v_order_id,
    v_user_id,
    v_order_status,
    CASE WHEN v_order_status = 'pending' THEN 'processing' ELSE v_order_status END,
    v_payment_status,
    'completed',
    'Order payment completed via ' || p_payment_method
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_number', p_order_number
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION handle_payment_success(text, text) TO authenticated;