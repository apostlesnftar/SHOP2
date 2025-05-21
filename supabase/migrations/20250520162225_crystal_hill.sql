/*
  # Include Shared Orders in Commission Calculations
  
  1. Changes
    - Update process_agent_commission function to include shared orders
    - Ensure agents receive commissions for orders paid through shared payment links
    - Fix commission calculation for referred customers' orders
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control for commission data
*/

-- Update the process_agent_commission function to handle shared orders
CREATE OR REPLACE FUNCTION process_agent_commission()
RETURNS TRIGGER AS $$
DECLARE
  order_user_id UUID;
  agent_user_id UUID;
  parent_agent_id UUID;
  order_total DECIMAL;
  agent_commission_rate DECIMAL;
  parent_commission_rate DECIMAL;
  agent_commission DECIMAL;
  parent_commission DECIMAL;
  referrer_id UUID;
BEGIN
  -- Only process if order status changed to 'delivered'
  IF NEW.status = 'delivered' AND OLD.status <> 'delivered' THEN
    -- Get order user and total
    SELECT user_id, total INTO order_user_id, order_total FROM orders WHERE id = NEW.id;
    
    -- First check if the user has a referrer (direct referral relationship)
    SELECT referrer_id INTO referrer_id
    FROM user_profiles
    WHERE id = order_user_id;
    
    -- If user has a referrer, create commission for the referrer
    IF referrer_id IS NOT NULL THEN
      -- Get the referrer's commission rate
      SELECT commission_rate INTO agent_commission_rate
      FROM agents
      WHERE user_id = referrer_id;
      
      -- If referrer is an agent, calculate commission
      IF agent_commission_rate IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (referrer_id, NEW.id, agent_commission, 'pending');
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = referrer_id;
        
        -- Get parent agent if exists
        SELECT parent_agent_id INTO parent_agent_id
        FROM agents
        WHERE user_id = referrer_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, NEW.id, parent_commission, 'pending');
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    ELSE
      -- Find the agent associated with this user (through parent_agent_id)
      SELECT a.user_id, a.parent_agent_id, a.commission_rate 
      INTO agent_user_id, parent_agent_id, agent_commission_rate
      FROM user_profiles up
      LEFT JOIN agents a ON a.user_id = up.id
      WHERE up.id = order_user_id;
      
      -- If the user is associated with an agent
      IF agent_user_id IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (agent_user_id, NEW.id, agent_commission, 'pending');
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = agent_user_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, NEW.id, parent_commission, 'pending');
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to handle shared order payment completion
CREATE OR REPLACE FUNCTION handle_shared_order_payment_completion()
RETURNS TRIGGER AS $$
DECLARE
  order_id UUID;
  order_user_id UUID;
  referrer_id UUID;
  agent_commission_rate DECIMAL;
  parent_agent_id UUID;
  parent_commission_rate DECIMAL;
  order_total DECIMAL;
  agent_commission DECIMAL;
  parent_commission DECIMAL;
BEGIN
  -- Only process if shared order status changed to 'completed'
  IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
    -- Get the order ID
    order_id := NEW.order_id;
    
    -- Get order details
    SELECT user_id, total INTO order_user_id, order_total
    FROM orders
    WHERE id = order_id;
    
    -- Check if the user has a referrer
    SELECT referrer_id INTO referrer_id
    FROM user_profiles
    WHERE id = order_user_id;
    
    -- If user has a referrer, create commission for the referrer
    IF referrer_id IS NOT NULL THEN
      -- Get the referrer's commission rate
      SELECT commission_rate, parent_agent_id INTO agent_commission_rate, parent_agent_id
      FROM agents
      WHERE user_id = referrer_id;
      
      -- If referrer is an agent, calculate commission
      IF agent_commission_rate IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (referrer_id, order_id, agent_commission, 'pending');
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = referrer_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, order_id, parent_commission, 'pending');
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for shared order payment completion
CREATE TRIGGER on_shared_order_completed
  AFTER UPDATE OF status ON shared_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status <> 'completed')
  EXECUTE FUNCTION handle_shared_order_payment_completion();

-- Update the process_friend_payment function to handle commission calculation
CREATE OR REPLACE FUNCTION process_friend_payment(
  p_share_id text,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shared_order record;
  v_order_id uuid;
  v_order_number text;
  v_user_id uuid;
  v_valid_payment_method boolean;
  v_referrer_id uuid;
BEGIN
  -- Get shared order with user_id
  SELECT 
    s.*,
    o.order_number,
    o.id as order_id,
    o.user_id
  INTO v_shared_order
  FROM shared_orders s
  JOIN orders o ON o.id = s.order_id
  WHERE s.share_id = p_share_id
  AND s.expires_at > now()
  AND s.status = 'pending'
  AND o.payment_method = 'friend_payment'
  AND o.payment_status = 'pending';
  
  -- Validate shared order
  IF v_shared_order IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Shared order not found, expired, or already paid'
    );
  END IF;
  
  -- Check if payment method is valid
  SELECT EXISTS (
    SELECT 1 FROM (
      -- Get available payment methods from payment_gateways
      SELECT 
        CASE 
          WHEN provider = 'stripe' THEN 'credit_card'
          WHEN provider = 'custom' THEN name
          ELSE provider
        END as method
      FROM payment_gateways
      WHERE is_active = true
      
      UNION ALL
      
      -- Add acacia_pay as a valid method
      SELECT 'acacia_pay' as method
    ) methods
    WHERE methods.method = p_payment_method
  ) INTO v_valid_payment_method;
  
  -- Validate payment method
  IF NOT v_valid_payment_method THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method: ' || p_payment_method
    );
  END IF;
  
  -- Store user_id for audit log
  v_user_id := v_shared_order.user_id;
  
  -- Update order status
  UPDATE orders
  SET 
    payment_status = 'completed',
    status = 'processing'
  WHERE id = v_shared_order.order_id
  AND payment_status = 'pending'
  RETURNING id INTO v_order_id;
  
  -- If order was updated successfully
  IF v_order_id IS NOT NULL THEN
    -- Create audit log manually to ensure user_id is set
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
    SET status = 'completed'
    WHERE share_id = p_share_id;
    
    -- Check if the user has a referrer
    SELECT referrer_id INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_user_id;
    
    -- The commission will be handled by the on_shared_order_completed trigger
    
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_order_id,
      'order_number', v_shared_order.order_number
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Failed to process payment'
  );
END;
$$;

-- Function to get shared order details with proper commission handling
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
GRANT EXECUTE ON FUNCTION process_agent_commission() TO authenticated;
GRANT EXECUTE ON FUNCTION handle_shared_order_payment_completion() TO authenticated;
GRANT EXECUTE ON FUNCTION process_friend_payment(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_shared_order_details(text) TO authenticated;