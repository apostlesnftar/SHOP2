-- Drop existing function first to avoid the return type error
DROP FUNCTION IF EXISTS create_team_member(uuid, text, text, text, numeric);

-- Create team member function with proper error handling
CREATE OR REPLACE FUNCTION create_team_member(
  p_agent_id UUID,
  p_email TEXT,
  p_username TEXT,
  p_password TEXT,
  p_commission_rate NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_is_agent BOOLEAN;
  v_agent_level INTEGER;
  v_new_user_level INTEGER;
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
  WHERE user_id = p_agent_id;
  
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

    -- Create user profile
    INSERT INTO public.user_profiles (
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
    INSERT INTO public.agents (
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
      p_agent_id,
      p_commission_rate,
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_team_member(uuid, text, text, text, numeric) TO authenticated;