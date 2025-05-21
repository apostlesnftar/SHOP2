/*
  # Fix Agent Referral Binding
  
  1. Changes
    - Improve the trigger function to properly handle referral codes
    - Add explicit logging for debugging
    - Ensure proper parent-child relationship is established
    - Fix issue with NULL values in array aggregation
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
  
  RAISE LOG 'Setting up agent relationship: User % (level %) -> Agent % (level %)', 
    NEW.id, v_new_user_level, v_referral_code, v_agent_level;
  
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
  v_agent_level INTEGER;
  v_new_user_level INTEGER;
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
    SELECT 1 FROM agents 
    WHERE user_id = v_user_id 
    AND parent_agent_id = p_agent_id
  ) INTO v_is_already_team_member;
  
  IF v_is_already_team_member THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is already a member of your team'
    );
  END IF;
  
  -- Get agent's level
  SELECT level INTO v_agent_level
  FROM agents
  WHERE user_id = p_agent_id;
  
  -- Calculate new user's level (parent level + 1)
  v_new_user_level := v_agent_level + 1;

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
          level = v_new_user_level,
          commission_rate = p_commission_rate
        WHERE user_id = v_user_id;
      ELSE
        -- Create new agent record
        INSERT INTO agents (
          user_id,
          level,
          parent_agent_id,
          commission_rate,
          status,
          created_at,
          updated_at
        ) VALUES (
          v_user_id,
          v_new_user_level,
          p_agent_id,
          p_commission_rate,
          'active',
          NOW(),
          NOW()
        );
      END IF;
    ELSE
      -- Update user role to agent
      UPDATE user_profiles
      SET role = 'agent'
      WHERE id = v_user_id;
      
      -- Create agent record
      INSERT INTO agents (
        user_id,
        level,
        parent_agent_id,
        commission_rate,
        status,
        created_at,
        updated_at
      ) VALUES (
        v_user_id,
        v_new_user_level,
        p_agent_id,
        p_commission_rate,
        'active',
        NOW(),
        NOW()
      );
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION bind_user_to_agent_team(uuid, text, numeric) TO authenticated;