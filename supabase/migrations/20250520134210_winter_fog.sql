/*
  # Fix Agent Referral Binding
  
  1. New Functions
    - `handle_user_registration_with_referral` - Improved trigger function to properly handle referral codes
    - Fixes the issue where users registering through referral links aren't being bound to agents
  
  2. Security
    - Ensures proper validation of referral codes
    - Maintains proper agent hierarchy
*/

-- Improved trigger function to handle user registration with referral
CREATE OR REPLACE FUNCTION handle_user_registration_with_referral()
RETURNS TRIGGER AS $$
DECLARE
  v_referral_code UUID;
  v_agent_level INTEGER;
  v_new_user_level INTEGER;
  v_is_agent BOOLEAN;
  v_username TEXT;
  v_user_exists BOOLEAN;
BEGIN
  -- Check if user has referral code in metadata
  BEGIN
    -- First try to get referral_code directly
    v_referral_code := (NEW.raw_user_meta_data->>'referral_code')::UUID;
    
    -- If that fails, check if it's in the ref parameter
    IF v_referral_code IS NULL THEN
      v_referral_code := (NEW.raw_user_meta_data->>'ref')::UUID;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- If referral code is not a valid UUID, ignore it
    v_referral_code := NULL;
  END;
  
  -- If no referral code, do nothing special
  IF v_referral_code IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if the referral code (agent ID) exists and is active
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
  
  -- Get username from metadata or email
  v_username := COALESCE(
    NEW.raw_user_meta_data->>'username', 
    split_part(NEW.email, '@', 1)
  );
  
  -- Check if user profile already exists
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = NEW.id
  ) INTO v_user_exists;
  
  -- Update or create user profile with agent role
  IF v_user_exists THEN
    UPDATE user_profiles
    SET 
      role = 'agent',
      username = COALESCE(username, v_username)
    WHERE id = NEW.id;
  ELSE
    INSERT INTO user_profiles (
      id,
      username,
      role,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      v_username,
      'agent',
      NOW(),
      NOW()
    );
  END IF;
  
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