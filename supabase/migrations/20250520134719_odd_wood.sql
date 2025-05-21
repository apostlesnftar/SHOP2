/*
  # Fix Agent Referral Binding
  
  1. Changes
    - Improve the trigger function to properly handle referral codes during registration
    - Add a new column to user_profiles to track referrer_id
    - Update handle_user_registration_with_referral function to use the new column
    - Ensure proper parent-child relationship is established in the agents table
*/

-- Add referrer_id column to user_profiles if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_profiles' 
    AND column_name = 'referrer_id'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN referrer_id UUID REFERENCES user_profiles(id);
  END IF;
END $$;

-- Create index on referrer_id for better query performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_referrer_id ON user_profiles(referrer_id);

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
    
    RAISE LOG 'Referral code found: %', v_referral_code;
  EXCEPTION WHEN OTHERS THEN
    -- If referral code is not a valid UUID, log and ignore it
    RAISE LOG 'Invalid referral code format: %', NEW.raw_user_meta_data->>'ref';
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
    RAISE LOG 'Invalid or inactive agent ID: %', v_referral_code;
    RETURN NEW; -- Invalid referral code, but continue with registration
  END IF;
  
  -- Get agent's level
  SELECT level INTO v_agent_level
  FROM agents
  WHERE user_id = v_referral_code;
  
  -- Calculate new user's level (parent level + 1)
  v_new_user_level := v_agent_level + 1;
  
  -- Check if user profile already exists
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = NEW.id
  ) INTO v_user_exists;
  
  -- Update or create user profile with agent role and referrer_id
  IF v_user_exists THEN
    UPDATE user_profiles
    SET 
      role = 'agent',
      username = COALESCE(username, v_username),
      referrer_id = v_referral_code
    WHERE id = NEW.id;
    
    RAISE LOG 'Updated existing user profile to agent role with referrer: % -> %', NEW.id, v_referral_code;
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
      'agent',
      v_referral_code,
      NOW(),
      NOW()
    );
    
    RAISE LOG 'Created new user profile with agent role and referrer: % -> %', NEW.id, v_referral_code;
  END IF;
  
  -- Create agent record with parent relationship
  BEGIN
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
    
    RAISE LOG 'Created/updated agent record with parent relationship: % -> %', NEW.id, v_referral_code;
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error creating agent record: %', SQLERRM;
  END;
  
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

-- Function to check if a user was referred by an agent
CREATE OR REPLACE FUNCTION was_referred_by_agent(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = p_user_id
    AND referrer_id IS NOT NULL
  );
END;
$$;

-- Function to get a user's referrer
CREATE OR REPLACE FUNCTION get_user_referrer(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  SELECT referrer_id INTO v_referrer_id
  FROM user_profiles
  WHERE id = p_user_id;
  
  RETURN v_referrer_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION was_referred_by_agent(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_referrer(UUID) TO authenticated;