/*
  # Update Agent Commission System for Shared Orders
  
  1. Changes
    - Update agent team statistics to include shared orders
    - Add function to get customer order statistics including shared orders
    - Ensure commissions are calculated for shared orders
    - Fix team member queries to include order statistics
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control
*/

-- Drop existing functions first to avoid return type errors
DROP FUNCTION IF EXISTS get_agent_team_members(uuid);
DROP FUNCTION IF EXISTS get_agent_dashboard_team(uuid, integer);

-- Update the get_agent_team_stats function to include shared orders
CREATE OR REPLACE FUNCTION get_agent_team_stats(p_agent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent boolean;
  v_team_size integer;
  v_total_earnings numeric(10,2);
  v_total_orders integer;
  v_total_order_amount numeric(10,2);
  v_processing_orders integer;
  v_processing_amount numeric(10,2);
  v_completed_orders integer;
  v_completed_amount numeric(10,2);
  v_team_member_ids uuid[];
  v_referred_customer_ids uuid[];
  v_shared_order_ids uuid[];
BEGIN
  -- Check if the user is an agent
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  -- If not an agent, return error
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an agent'
    );
  END IF;
  
  -- Get all agent team member IDs
  SELECT array_agg(user_id) INTO v_team_member_ids
  FROM agents
  WHERE parent_agent_id = p_agent_id;
  
  -- Get all referred customer IDs
  SELECT array_agg(id) INTO v_referred_customer_ids
  FROM user_profiles
  WHERE referrer_id = p_agent_id
  AND role = 'customer'
  AND NOT EXISTS (
    -- Exclude users who are already agents
    SELECT 1 FROM agents a WHERE a.user_id = user_profiles.id
  );
  
  -- Handle null arrays
  IF v_team_member_ids IS NULL THEN
    v_team_member_ids := ARRAY[]::uuid[];
  END IF;
  
  IF v_referred_customer_ids IS NULL THEN
    v_referred_customer_ids := ARRAY[]::uuid[];
  END IF;
  
  -- Get shared order IDs for referred customers
  SELECT array_agg(so.order_id) INTO v_shared_order_ids
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE o.user_id = ANY(v_referred_customer_ids)
  AND (so.status = 'completed' OR o.status = 'processing' OR o.status = 'delivered');
  
  -- Handle null array
  IF v_shared_order_ids IS NULL THEN
    v_shared_order_ids := ARRAY[]::uuid[];
  END IF;
  
  -- Calculate team size (agents + referred customers)
  v_team_size := array_length(v_team_member_ids, 1);
  IF v_team_size IS NULL THEN
    v_team_size := 0;
  END IF;
  
  v_team_size := v_team_size + array_length(v_referred_customer_ids, 1);
  IF v_team_size IS NULL THEN
    v_team_size := 0;
  END IF;
  
  -- Get total earnings for the team (agents only)
  SELECT COALESCE(SUM(total_earnings), 0) INTO v_total_earnings
  FROM agents
  WHERE user_id = ANY(v_team_member_ids)
  OR user_id = p_agent_id;
  
  -- Get total orders and amount for both agents and referred customers
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_total_orders,
    v_total_order_amount
  FROM orders o
  WHERE (
    -- Orders from agent team members
    EXISTS (
      SELECT 1 FROM commissions c
      WHERE c.order_id = o.id
      AND c.agent_id = ANY(v_team_member_ids || p_agent_id)
    )
    OR
    -- Orders from referred customers
    o.user_id = ANY(v_referred_customer_ids)
    OR
    -- Shared orders from referred customers
    o.id = ANY(v_shared_order_ids)
  );
  
  -- Get processing orders and amount
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_processing_orders,
    v_processing_amount
  FROM orders o
  WHERE o.status = 'processing'
  AND (
    -- Orders from agent team members
    EXISTS (
      SELECT 1 FROM commissions c
      WHERE c.order_id = o.id
      AND c.agent_id = ANY(v_team_member_ids || p_agent_id)
    )
    OR
    -- Orders from referred customers
    o.user_id = ANY(v_referred_customer_ids)
    OR
    -- Shared orders from referred customers
    o.id = ANY(v_shared_order_ids)
  );
  
  -- Get completed orders and amount
  SELECT 
    COUNT(DISTINCT o.id),
    COALESCE(SUM(o.total), 0)
  INTO 
    v_completed_orders,
    v_completed_amount
  FROM orders o
  WHERE o.status = 'delivered'
  AND (
    -- Orders from agent team members
    EXISTS (
      SELECT 1 FROM commissions c
      WHERE c.order_id = o.id
      AND c.agent_id = ANY(v_team_member_ids || p_agent_id)
    )
    OR
    -- Orders from referred customers
    o.user_id = ANY(v_referred_customer_ids)
    OR
    -- Shared orders from referred customers
    o.id = ANY(v_shared_order_ids)
  );
  
  -- Return the statistics as JSON
  RETURN jsonb_build_object(
    'success', true,
    'team_size', v_team_size,
    'total_earnings', v_total_earnings,
    'total_orders', v_total_orders,
    'total_amount', v_total_order_amount,
    'processing_orders', v_processing_orders,
    'processing_amount', v_processing_amount,
    'completed_orders', v_completed_orders,
    'completed_amount', v_completed_amount
  );
END;
$$;

-- Function to get customer order statistics including shared orders
CREATE OR REPLACE FUNCTION get_customer_order_stats(p_customer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_orders integer;
  v_total_amount numeric(10,2);
  v_processing_orders integer;
  v_processing_amount numeric(10,2);
  v_completed_orders integer;
  v_completed_amount numeric(10,2);
  v_shared_order_ids uuid[];
BEGIN
  -- Get shared order IDs for this customer
  SELECT array_agg(so.order_id) INTO v_shared_order_ids
  FROM shared_orders so
  JOIN orders o ON o.id = so.order_id
  WHERE o.user_id = p_customer_id
  AND (so.status = 'completed' OR o.status = 'processing' OR o.status = 'delivered');
  
  -- Handle null array
  IF v_shared_order_ids IS NULL THEN
    v_shared_order_ids := ARRAY[]::uuid[];
  END IF;
  
  -- Get total orders and amount
  SELECT 
    COUNT(DISTINCT id),
    COALESCE(SUM(total), 0)
  INTO 
    v_total_orders,
    v_total_amount
  FROM orders
  WHERE user_id = p_customer_id
  OR id = ANY(v_shared_order_ids);
  
  -- Get processing orders and amount
  SELECT 
    COUNT(DISTINCT id),
    COALESCE(SUM(total), 0)
  INTO 
    v_processing_orders,
    v_processing_amount
  FROM orders
  WHERE status = 'processing'
  AND (user_id = p_customer_id OR id = ANY(v_shared_order_ids));
  
  -- Get completed orders and amount
  SELECT 
    COUNT(DISTINCT id),
    COALESCE(SUM(total), 0)
  INTO 
    v_completed_orders,
    v_completed_amount
  FROM orders
  WHERE status = 'delivered'
  AND (user_id = p_customer_id OR id = ANY(v_shared_order_ids));
  
  -- Return the statistics as JSON
  RETURN jsonb_build_object(
    'success', true,
    'total_orders', v_total_orders,
    'total_amount', v_total_amount,
    'processing_orders', v_processing_orders,
    'processing_amount', v_processing_amount,
    'completed_orders', v_completed_orders,
    'completed_amount', v_completed_amount
  );
END;
$$;

-- Update the handle_shared_order_payment_completion function to ensure commissions are calculated
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
      -- Get the referrer's commission rate and parent
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
    
    -- Update the order status to processing if it's still pending
    UPDATE orders
    SET 
      status = CASE WHEN status = 'pending' THEN 'processing' ELSE status END,
      payment_status = 'completed'
    WHERE id = order_id
    AND payment_status = 'pending';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for shared order payment completion if it doesn't exist
DROP TRIGGER IF EXISTS on_shared_order_completed ON shared_orders;
CREATE TRIGGER on_shared_order_completed
  AFTER UPDATE OF status ON shared_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status <> 'completed')
  EXECUTE FUNCTION handle_shared_order_payment_completion();

-- Function to get all team members for an agent (including referred customers with order stats)
CREATE FUNCTION get_agent_team_members(p_agent_id uuid)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  commission_rate numeric,
  total_earnings numeric,
  current_balance numeric,
  status text,
  created_at timestamptz,
  is_agent boolean,
  order_count integer,
  order_total numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return direct team members (agents where parent_agent_id = p_agent_id)
  RETURN QUERY
  SELECT 
    a.user_id,
    up.username,
    up.full_name,
    a.level,
    a.commission_rate,
    a.total_earnings,
    a.current_balance,
    a.status,
    a.created_at,
    TRUE as is_agent,
    COALESCE((
      SELECT COUNT(DISTINCT o.id)
      FROM orders o
      JOIN commissions c ON c.order_id = o.id
      WHERE c.agent_id = a.user_id
    ), 0) as order_count,
    COALESCE((
      SELECT SUM(o.total)
      FROM orders o
      JOIN commissions c ON c.order_id = o.id
      WHERE c.agent_id = a.user_id
    ), 0) as order_total
  FROM agents a
  JOIN user_profiles up ON up.id = a.user_id
  WHERE a.parent_agent_id = p_agent_id
  
  UNION
  
  -- Include customers who were referred by this agent
  SELECT 
    up.id as user_id,
    up.username,
    up.full_name,
    0 as level, -- Level 0 for customers
    0 as commission_rate,
    0 as total_earnings,
    0 as current_balance,
    'customer' as status,
    up.created_at,
    FALSE as is_agent,
    COALESCE((
      SELECT COUNT(DISTINCT o.id)
      FROM orders o
      LEFT JOIN shared_orders so ON so.order_id = o.id
      WHERE o.user_id = up.id
      OR (so.status = 'completed' AND o.user_id = up.id)
    ), 0) as order_count,
    COALESCE((
      SELECT SUM(o.total)
      FROM orders o
      LEFT JOIN shared_orders so ON so.order_id = o.id
      WHERE o.user_id = up.id
      OR (so.status = 'completed' AND o.user_id = up.id)
    ), 0) as order_total
  FROM user_profiles up
  WHERE up.referrer_id = p_agent_id
  AND up.role = 'customer'
  AND NOT EXISTS (
    -- Exclude users who are already agents
    SELECT 1 FROM agents a WHERE a.user_id = up.id
  );
END;
$$;

-- Function to get team members for dashboard display (limited to 5)
CREATE FUNCTION get_agent_dashboard_team(p_agent_id uuid, p_limit integer DEFAULT 5)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  status text,
  created_at timestamptz,
  total_earnings numeric,
  is_agent boolean,
  order_count integer,
  order_total numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return team members from both parent_agent_id and referrer_id relationships
  RETURN QUERY
  (
    -- Get team members via parent_agent_id (agents)
    SELECT 
      a.user_id,
      up.username,
      up.full_name,
      a.level,
      a.status,
      a.created_at,
      a.total_earnings,
      TRUE as is_agent,
      COALESCE((
        SELECT COUNT(DISTINCT o.id)
        FROM orders o
        JOIN commissions c ON c.order_id = o.id
        WHERE c.agent_id = a.user_id
      ), 0) as order_count,
      COALESCE((
        SELECT SUM(o.total)
        FROM orders o
        JOIN commissions c ON c.order_id = o.id
        WHERE c.agent_id = a.user_id
      ), 0) as order_total
    FROM agents a
    JOIN user_profiles up ON up.id = a.user_id
    WHERE a.parent_agent_id = p_agent_id
    
    UNION
    
    -- Get team members via referrer_id (customers)
    SELECT 
      up.id as user_id,
      up.username,
      up.full_name,
      0 as level,
      'customer' as status,
      up.created_at,
      0 as total_earnings,
      FALSE as is_agent,
      COALESCE((
        SELECT COUNT(DISTINCT o.id)
        FROM orders o
        LEFT JOIN shared_orders so ON so.order_id = o.id
        WHERE o.user_id = up.id
        OR (so.status = 'completed' AND o.user_id = up.id)
      ), 0) as order_count,
      COALESCE((
        SELECT SUM(o.total)
        FROM orders o
        LEFT JOIN shared_orders so ON so.order_id = o.id
        WHERE o.user_id = up.id
        OR (so.status = 'completed' AND o.user_id = up.id)
      ), 0) as order_total
    FROM user_profiles up
    WHERE up.referrer_id = p_agent_id
    AND up.role = 'customer'
    AND NOT EXISTS (
      -- Exclude users who are already agents
      SELECT 1 FROM agents a WHERE a.user_id = up.id
    )
  )
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_customer_order_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION handle_shared_order_payment_completion() TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;