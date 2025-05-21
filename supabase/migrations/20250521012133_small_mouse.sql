/*
  # Remove order_number column from shared_orders table
  
  1. Changes
    - Remove the order_number column from shared_orders table
    - Update share_order function to not write to order_number
    - Update process_friend_payment function to get order_number from orders table
    - Update get_shared_order_details function to get order_number from orders table
  
  2. Purpose
    - Fix the "column reference order_number is ambiguous" error
    - Ensure all functions use orders.order_number instead of shared_orders.order_number
*/

-- 1. Remove order_number column from shared_orders table
ALTER TABLE shared_orders 
DROP COLUMN IF EXISTS order_number;

-- 2. Update share_order function to not write to order_number
DROP FUNCTION IF EXISTS public.share_order(uuid);

CREATE OR REPLACE FUNCTION public.share_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_share_id text;
  v_expires_at timestamptz;
  v_order_status text;
  v_payment_method text;
  v_shared_order_id uuid;
  v_referrer_id uuid;
  v_order_number text;
BEGIN
  -- Get order details
  SELECT 
    o.user_id,
    o.status,
    o.payment_method,
    o.order_number
  INTO 
    v_user_id, 
    v_order_status, 
    v_payment_method,
    v_order_number
  FROM orders o
  WHERE o.id = p_order_id;

  -- Verify the order exists
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Verify the order belongs to the current user
  IF v_user_id != auth.uid() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Not authorized to share this order'
    );
  END IF;
  
  -- Verify the order is using friend payment
  IF v_payment_method != 'friend_payment' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Only friend payment orders can be shared'
    );
  END IF;
  
  -- Verify the order is in a shareable state
  IF v_order_status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order cannot be shared in its current state'
    );
  END IF;

  -- Get the referrer_id from user_profiles
  SELECT up.referrer_id INTO v_referrer_id
  FROM user_profiles up
  WHERE up.id = v_user_id;

  -- Calculate expiry timestamp (24 hours)
  v_expires_at := now() + interval '24 hours';

  -- Generate a unique share ID
  v_share_id := encode(gen_random_bytes(6), 'hex');

  -- Create or update the shared order record with referrer_id
  INSERT INTO shared_orders (
    share_id,
    order_id,
    expires_at,
    referrer_id
  ) VALUES (
    v_share_id,
    p_order_id,
    v_expires_at,
    v_referrer_id
  )
  ON CONFLICT (order_id) 
  DO UPDATE SET
    share_id = v_share_id,
    expires_at = v_expires_at,
    status = 'pending',
    referrer_id = v_referrer_id,
    updated_at = now();

  -- Return the share details
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_share_id,
    'expires_at', v_expires_at,
    'order_id', p_order_id,
    'order_number', v_order_number
  );
END;
$$;

-- 3. Update process_friend_payment function to get order_number from orders table
DROP FUNCTION IF EXISTS process_friend_payment(p_share_id text, p_payment_method text);

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
  v_shared_order_referrer_id uuid;
  v_order_number text;
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
    so.referrer_id AS shared_order_referrer_id,
    o.order_number, -- Get order_number directly from orders table
    o.user_id,
    o.total
  INTO 
    v_order_id,
    v_shared_order_referrer_id,
    v_order_number,
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
  IF v_shared_order_referrer_id IS NULL THEN
    SELECT up.referrer_id INTO v_shared_order_referrer_id
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
  IF v_shared_order_referrer_id IS NOT NULL THEN
    -- Get the referrer's commission rate and parent
    SELECT a.commission_rate, a.parent_agent_id 
    INTO v_agent_commission_rate, v_parent_agent_id
    FROM agents a
    WHERE a.user_id = v_shared_order_referrer_id;
    
    -- If referrer is an agent, calculate commission
    IF v_agent_commission_rate IS NOT NULL THEN
      -- Calculate commission
      v_agent_commission := (v_order_total * v_agent_commission_rate / 100);
      
      -- Create commission record
      INSERT INTO commissions (agent_id, order_id, amount, status)
      VALUES (v_shared_order_referrer_id, v_order_id, v_agent_commission, 'pending');
      
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
        v_shared_order_referrer_id,
        v_agent_commission,
        'commission',
        'completed',
        v_order_id,
        'Commission from shared order #' || v_order_number,
        NOW()
      ) RETURNING id INTO v_transaction_id;
      
      -- Update agent total earnings and balance
      UPDATE agents
      SET total_earnings = total_earnings + v_agent_commission,
          current_balance = current_balance + v_agent_commission
      WHERE user_id = v_shared_order_referrer_id;
      
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
          'Team commission from shared order #' || v_order_number,
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
    'order_number', v_order_number
  );
END;
$$;

-- 4. Update get_shared_order_details function to get order_number from orders table
DROP FUNCTION IF EXISTS get_shared_order_details(text);

CREATE OR REPLACE FUNCTION get_shared_order_details(p_share_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order record;
  v_order_items jsonb;
  v_user_id uuid;
  v_referrer_id uuid;
BEGIN
  -- Get shared order details
  SELECT * INTO v_shared_order
  FROM shared_orders
  WHERE share_id = p_share_id
  AND expires_at > now()
  AND status = 'pending';
  
  -- Check if shared order exists and is valid
  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found or expired'
    );
  END IF;
  
  -- Get order details
  SELECT 
    o.*,
    json_agg(
      jsonb_build_object(
        'id', oi.id,
        'product_id', oi.product_id,
        'quantity', oi.quantity,
        'price', oi.price,
        'product', jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'images', p.images
        )
      )
    ) as items,
    o.user_id
  INTO v_order
  FROM orders o
  LEFT JOIN order_items oi ON oi.order_id = o.id
  LEFT JOIN products p ON p.id = oi.product_id
  WHERE o.id = v_shared_order.order_id
  GROUP BY o.id;
  
  -- Get user's referrer if any
  SELECT referrer_id INTO v_referrer_id
  FROM user_profiles
  WHERE id = v_order.user_id;
  
  -- Return full order details
  RETURN jsonb_build_object(
    'success', true,
    'share_id', v_shared_order.share_id,
    'expires_at', v_shared_order.expires_at,
    'status', v_shared_order.status,
    'order', jsonb_build_object(
      'id', v_order.id,
      'order_number', v_order.order_number,
      'status', v_order.status,
      'payment_status', v_order.payment_status,
      'subtotal', v_order.subtotal,
      'tax', v_order.tax,
      'shipping', v_order.shipping,
      'total', v_order.total,
      'items', v_order.items,
      'has_referrer', v_referrer_id IS NOT NULL
    )
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION share_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_shared_order_details(text) TO authenticated;