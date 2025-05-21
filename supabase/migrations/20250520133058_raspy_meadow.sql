/*
  # Add function to handle user registration with referral
  
  1. New Functions
    - `handle_user_registration_with_referral`: Trigger function to handle user registration with referral code
      - Automatically adds new users to the referring agent's team
      - Sets appropriate agent level and commission rate
      - Updates user role to agent
*/

-- Trigger function to handle user registration with referral
CREATE OR REPLACE FUNCTION handle_user_registration_with_referral()
RETURNS TRIGGER AS $$
DECLARE
  v_referral_code UUID;
  v_agent_level INTEGER;
  v_new_user_level INTEGER;
  v_is_agent BOOLEAN;
BEGIN
  -- Check if user has referral code in metadata
  v_referral_code := (NEW.raw_user_meta_data->>'referral_code')::UUID;
  
  -- If no referral code, do nothing
  IF v_referral_code IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if the referral code (agent ID) exists
  SELECT EXISTS (
    SELECT 1 FROM agents 
    WHERE user_id = v_referral_code
    AND status = 'active'
  ) INTO v_is_agent;
  
  IF NOT v_is_agent THEN
    RETURN NEW; -- Invalid referral code, but continue with registration
  END IF;
  
  -- Get agent's level
  SELECT level INTO v_agent_level
  FROM agents
  WHERE user_id = v_referral_code;
  
  -- Calculate new user's level (parent level + 1)
  v_new_user_level := v_agent_level + 1;
  
  -- Create user profile with agent role
  INSERT INTO user_profiles (
    id,
    username,
    role,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    'agent',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET role = 'agent';
  
  -- Create agent record with parent relationship
  INSERT INTO agents (
    user_id,
    level,
    parent_agent_id,
    commission_rate,
    status,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    v_new_user_level,
    v_referral_code,
    3.0, -- Default commission rate for referred users
    'active',
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET 
    parent_agent_id = v_referral_code,
    level = v_new_user_level;
  
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Log error but don't prevent user creation
    RAISE NOTICE 'Error in handle_user_registration_with_referral: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for user registration with referral
DROP TRIGGER IF EXISTS on_auth_user_created_with_referral ON auth.users;
CREATE TRIGGER on_auth_user_created_with_referral
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_registration_with_referral();