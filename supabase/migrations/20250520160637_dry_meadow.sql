-- Drop existing functions first to avoid return type errors
DROP FUNCTION IF EXISTS get_agent_team_members(uuid);
DROP FUNCTION IF EXISTS get_agent_dashboard_team(uuid, integer);

-- Improved trigger function to handle user registration with referral
CREATE OR REPLACE FUNCTION handle_user_registration_with_referral()
RETURNS TRIGGER AS $$
DECLARE
  v_referral_code UUID;
  v_agent_exists BOOLEAN;
  v_username TEXT;
  v_user_exists BOOLEAN;
  v_ref_param TEXT;
BEGIN
  -- Get username from metadata or email
  v_username := COALESCE(
    NEW.raw_user_meta_data->>'username', 
    split_part(NEW.email, '@', 1)
  );

  -- Check for referral code in multiple places
  BEGIN
    -- First try to get referral_code directly
    v_referral_code := (NEW.raw_user_meta_data->>'referral_code')::UUID;
    
    -- If that fails, check if it's in the ref parameter
    IF v_referral_code IS NULL THEN
      v_ref_param := NEW.raw_user_meta_data->>'ref';
      IF v_ref_param IS NOT NULL THEN
        v_referral_code := v_ref_param::UUID;
      END IF;
    END IF;
    
    RAISE LOG 'Referral code found in metadata: %', v_referral_code;
  EXCEPTION WHEN OTHERS THEN
    -- If referral code is not a valid UUID, log and ignore it
    RAISE LOG 'Invalid referral code format: %', NEW.raw_user_meta_data;
    v_referral_code := NULL;
  END;
  
  -- If no referral code, do nothing special
  IF v_referral_code IS NULL THEN
    RAISE LOG 'No referral code found for user %', NEW.id;
    RETURN NEW;
  END IF;
  
  -- Check if the referral code (agent ID) exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = v_referral_code
  ) INTO v_agent_exists;
  
  IF NOT v_agent_exists THEN
    RAISE LOG 'Invalid agent ID: %', v_referral_code;
    RETURN NEW; -- Invalid referral code, but continue with registration
  END IF;
  
  RAISE LOG 'Setting up referral relationship: User % -> Agent %', 
    NEW.id, v_referral_code;
  
  -- Check if user profile already exists
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = NEW.id
  ) INTO v_user_exists;
  
  -- Update or create user profile with customer role and referrer_id
  IF v_user_exists THEN
    UPDATE user_profiles
    SET 
      role = 'customer', -- Set as customer, not agent
      username = COALESCE(username, v_username),
      referrer_id = v_referral_code
    WHERE id = NEW.id;
    
    RAISE LOG 'Updated existing user profile to customer role with referrer: % -> %', NEW.id, v_referral_code;
  ELSE
    INSERT INTO user_profiles (
      id,
      username,
      role,
      referrer_id,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      v_username,
      'customer', -- Set as customer, not agent
      v_referral_code,
      NOW(),
      NOW()
    );
    
    RAISE LOG 'Created new user profile with customer role and referrer: % -> %', NEW.id, v_referral_code;
  END IF;
  
  -- Do NOT create an agent record for referred users
  
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Log error but don't prevent user creation
    RAISE LOG 'Error in handle_user_registration_with_referral: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for user registration with referral
DROP TRIGGER IF EXISTS on_auth_user_created_with_referral ON auth.users;
CREATE TRIGGER on_auth_user_created_with_referral
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_registration_with_referral();

-- Create new function to get all team members for an agent (including referred customers)
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
  is_agent boolean
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
    TRUE as is_agent
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
    FALSE as is_agent
  FROM user_profiles up
  WHERE up.referrer_id = p_agent_id
  AND up.role = 'customer'
  AND NOT EXISTS (
    -- Exclude users who are already agents
    SELECT 1 FROM agents a WHERE a.user_id = up.id
  );
END;
$$;

-- Create function to get team members for dashboard display (limited to 5)
CREATE FUNCTION get_agent_dashboard_team(p_agent_id uuid, p_limit integer DEFAULT 5)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  status text,
  created_at timestamptz,
  total_earnings numeric,
  is_agent boolean
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
      TRUE as is_agent
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
      FALSE as is_agent
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

-- Improved function to count team members by parent agent
CREATE OR REPLACE FUNCTION count_team_members_by_parent()
RETURNS TABLE (
  parent_agent_id uuid,
  count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    parent_id,
    COUNT(user_id)::bigint
  FROM (
    -- Count team members via parent_agent_id (agents)
    SELECT 
      a.parent_agent_id as parent_id,
      a.user_id
    FROM agents a
    WHERE a.parent_agent_id IS NOT NULL
    
    UNION
    
    -- Count team members via referrer_id (customers)
    SELECT 
      up.referrer_id as parent_id,
      up.id as user_id
    FROM user_profiles up
    WHERE up.referrer_id IS NOT NULL
    AND up.role = 'customer'
    AND NOT EXISTS (
      -- Exclude users who are already agents
      SELECT 1 FROM agents a WHERE a.user_id = up.id
    )
  ) as combined_team
  GROUP BY parent_id;
END;
$$;

-- Function to get comprehensive team statistics for an agent
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
  WHERE user_id = ANY(v_team_member_ids);
  
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
      AND c.agent_id = ANY(v_team_member_ids)
    )
    OR
    -- Orders from referred customers
    o.user_id = ANY(v_referred_customer_ids)
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
      AND c.agent_id = ANY(v_team_member_ids)
    )
    OR
    -- Orders from referred customers
    o.user_id = ANY(v_referred_customer_ids)
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
      AND c.agent_id = ANY(v_team_member_ids)
    )
    OR
    -- Orders from referred customers
    o.user_id = ANY(v_referred_customer_ids)
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

-- Function to bind an existing user to an agent's team by username
CREATE OR REPLACE FUNCTION bind_user_to_agent_team(
  p_agent_id UUID,
  p_username TEXT,
  p_commission_rate NUMERIC DEFAULT 3.0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_is_agent BOOLEAN;
  v_is_already_team_member BOOLEAN;
BEGIN
  -- Check if the agent exists
  SELECT EXISTS (
    SELECT 1 FROM agents WHERE user_id = p_agent_id
  ) INTO v_is_agent;
  
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Agent not found'
    );
  END IF;
  
  -- Input validation
  IF p_commission_rate < 0 OR p_commission_rate > 100 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Commission rate must be between 0 and 100'
    );
  END IF;

  -- Find user by username
  SELECT id, role INTO v_user_id, v_user_role
  FROM user_profiles
  WHERE username = p_username;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  -- Check if user is already a team member of this agent
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = v_user_id 
    AND referrer_id = p_agent_id
  ) INTO v_is_already_team_member;
  
  IF v_is_already_team_member THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is already a member of your team'
    );
  END IF;
  
  -- Start transaction
  BEGIN
    -- Update user_profiles to set referrer_id
    UPDATE user_profiles
    SET referrer_id = p_agent_id
    WHERE id = v_user_id;
    
    -- If user is already an agent, update their parent
    IF v_user_role = 'agent' THEN
      -- Check if user already has an agent record
      IF EXISTS (SELECT 1 FROM agents WHERE user_id = v_user_id) THEN
        -- Update the agent record
        UPDATE agents
        SET 
          parent_agent_id = p_agent_id,
          commission_rate = p_commission_rate
        WHERE user_id = v_user_id;
      ELSE
        -- Create new agent record
        INSERT INTO agents (
          user_id,
          parent_agent_id,
          commission_rate,
          status,
          created_at,
          updated_at
        ) VALUES (
          v_user_id,
          p_agent_id,
          p_commission_rate,
          'active',
          NOW(),
          NOW()
        );
      END IF;
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'user_id', v_user_id,
      'was_agent', v_user_role = 'agent'
    );

  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'This user is already part of a team'
      );
    WHEN others THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION count_team_members_by_parent() TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_team_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION bind_user_to_agent_team(uuid, text, numeric) TO authenticated;