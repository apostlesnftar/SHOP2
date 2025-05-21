/*
  # Fix Agent Referral User Role
  
  1. Changes
    - Update handle_user_registration_with_referral function to set role as 'customer' instead of 'agent'
    - Ensure users registered through referral links are properly tracked in user_profiles.referrer_id
    - Update team member query functions to include customers referred by agents
  
  2. Security
    - Maintain existing security context
    - Ensure proper access control between agents and referred customers
*/

-- Improved trigger function to handle user registration with referral
CREATE OR REPLACE FUNCTION handle_user_registration_with_referral()
RETURNS TRIGGER AS $$
DECLARE
  v_referral_code UUID;
  v_agent_level INTEGER;
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
  SELECT level INTO v_agent_level
  FROM agents
  WHERE user_id = v_referral_code;
  
  IF v_agent_level IS NULL THEN
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

-- Function to get all team members for an agent (including referred customers)
CREATE OR REPLACE FUNCTION get_agent_team_members(p_agent_id uuid)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  commission_rate numeric,
  total_earnings numeric,
  current_balance numeric,
  status text,
  created_at timestamptz
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Return direct team members (where parent_agent_id = p_agent_id)
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
    a.created_at
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
    up.created_at
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
CREATE OR REPLACE FUNCTION get_agent_dashboard_team(p_agent_id uuid, p_limit integer DEFAULT 5)
RETURNS TABLE (
  user_id uuid,
  username text,
  full_name text,
  level integer,
  status text,
  created_at timestamptz,
  total_earnings numeric
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
      a.total_earnings
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
      0 as total_earnings
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_agent_dashboard_team(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION count_team_members_by_parent() TO authenticated;