/*
  # Implement Referral Link Functionality
  
  1. New Functions
    - `bind_user_to_agent_team` - Binds an existing user to an agent's team
    - `register_with_referral` - Registers a new user with a referral code
    
  2. Security
    - Functions are accessible to authenticated users
    - Proper validation and error handling
*/

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

-- Function to handle user registration with referral code
CREATE OR REPLACE FUNCTION register_with_referral(
  p_username TEXT,
  p_email TEXT,
  p_password TEXT,
  p_referral_code UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_agent_id UUID := p_referral_code;
  v_agent_level INTEGER;
  v_new_user_level INTEGER;
  v_is_agent BOOLEAN;
BEGIN
  -- Check if the referral code (agent ID) exists
  SELECT EXISTS (
    SELECT 1 FROM agents 
    WHERE user_id = v_agent_id
    AND status = 'active'
  ) INTO v_is_agent;
  
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid referral code'
    );
  END IF;
  
  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Email already exists'
    );
  END IF;
  
  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM user_profiles WHERE username = p_username) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Username already exists'
    );
  END IF;
  
  -- Get agent's level
  SELECT level INTO v_agent_level
  FROM agents
  WHERE user_id = v_agent_id;
  
  -- Calculate new user's level (parent level + 1)
  v_new_user_level := v_agent_level + 1;
  
  -- Start transaction
  BEGIN
    -- Create auth user
    v_user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data
    )
    VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      p_email,
      crypt(p_password, gen_salt('bf')),
      NOW(),
      NOW(),
      NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('username', p_username)
    );
    
    -- Create user profile with agent role
    INSERT INTO user_profiles (
      id,
      username,
      role,
      created_at,
      updated_at
    )
    VALUES (
      v_user_id,
      p_username,
      'agent',
      NOW(),
      NOW()
    );
    
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
      v_user_id,
      v_new_user_level,
      v_agent_id,
      3.0, -- Default commission rate for referred users
      'active',
      NOW(),
      NOW()
    );
    
    RETURN jsonb_build_object(
      'success', true,
      'user_id', v_user_id
    );
    
  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'A user with this email or username already exists'
      );
    WHEN others THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;

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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION bind_user_to_agent_team(uuid, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION register_with_referral(text, text, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION register_with_referral(text, text, text, uuid) TO authenticated;