/*
  # Fix ambiguous user_id reference and add agent user creation
  
  1. Changes
    - Fix the ambiguous user_id column reference in get_agent_team_members function
    - Add function for agents to create new users with direct password setting
    - Ensure proper table aliases are used in all queries
  
  2. Security
    - Maintain security definer context for all functions
    - Ensure proper permission checks for user creation
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS get_agent_team_members(uuid);

-- Create a new version with explicit table aliases for all column references
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
  LEFT JOIN user_profiles up ON up.id = a.user_id
  WHERE a.parent_agent_id = p_agent_id;
END;
$$;

-- Function for agents to create new team members with direct password setting
CREATE OR REPLACE FUNCTION create_team_member(
  p_agent_id uuid,
  p_email text,
  p_username text,
  p_password text,
  p_commission_rate numeric DEFAULT 3.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_agent boolean;
  v_new_user_id uuid;
  v_agent_level integer;
  v_new_user_level integer;
BEGIN
  -- Check if the agent exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_agent_id
    AND status = 'active'
  ) INTO v_is_agent;
  
  -- If not an active agent, return error
  IF NOT v_is_agent THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an active agent'
    );
  END IF;
  
  -- Validate inputs
  IF p_email IS NULL OR p_username IS NULL OR p_password IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Email, username, and password are required'
    );
  END IF;
  
  -- Check if email already exists
  IF EXISTS (
    SELECT 1 FROM auth.users
    WHERE email = p_email
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Email already in use'
    );
  END IF;
  
  -- Get agent's level
  SELECT level INTO v_agent_level
  FROM agents
  WHERE user_id = p_agent_id;
  
  -- Calculate new user's level (parent level + 1)
  v_new_user_level := v_agent_level + 1;
  
  -- Create the user in auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    p_email,
    crypt(p_password, gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'providers', ARRAY['email']
    ),
    jsonb_build_object(
      'username', p_username
    ),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO v_new_user_id;
  
  -- Create user profile with agent role
  INSERT INTO user_profiles (
    id,
    username,
    role,
    created_at,
    updated_at
  ) VALUES (
    v_new_user_id,
    p_username,
    'agent',
    NOW(),
    NOW()
  );
  
  -- Create agent record with parent relationship
  INSERT INTO agents (
    user_id,
    parent_agent_id,
    level,
    commission_rate,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_new_user_id,
    p_agent_id,
    v_new_user_level,
    p_commission_rate,
    'active',
    NOW(),
    NOW()
  );
  
  -- Return success with new user ID
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_new_user_id,
    'message', 'Team member created successfully'
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_agent_team_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_team_member(uuid, text, text, text, numeric) TO authenticated;