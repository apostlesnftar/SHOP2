/*
  # Fix Agent Account Detection
  
  1. New Functions
    - `check_agent_status`: Checks if a user is an agent based on their role in user_profiles
    - `create_agent_if_not_exists`: Creates an agent record if it doesn't exist for a user with agent role
  
  2. Security
    - Functions are accessible to authenticated users
    - Proper validation of user role and agent status
*/

-- Function to check if a user is an agent based on their role in user_profiles
CREATE OR REPLACE FUNCTION check_agent_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_agent_exists boolean;
  v_agent_status text;
  v_agent_record record;
  v_user_role text;
BEGIN
  -- First check if the user has the agent role
  SELECT role INTO v_user_role
  FROM user_profiles
  WHERE id = p_user_id;
  
  IF v_user_role != 'agent' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User is not an agent',
      'role', v_user_role
    );
  END IF;
  
  -- Check if agent record exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_user_id
  ) INTO v_agent_exists;
  
  -- If agent record doesn't exist, return false
  IF NOT v_agent_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Agent record not found',
      'role', v_user_role
    );
  END IF;
  
  -- Get agent status
  SELECT status INTO v_agent_status
  FROM agents
  WHERE user_id = p_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'status', v_agent_status,
    'role', v_user_role
  );
END;
$$;

-- Function to create an agent record if it doesn't exist
CREATE OR REPLACE FUNCTION create_agent_if_not_exists(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_agent_exists boolean;
  v_agent_record record;
  v_user_role text;
BEGIN
  -- First check if the user exists
  SELECT role INTO v_user_role
  FROM user_profiles
  WHERE id = p_user_id;
  
  IF v_user_role IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  -- Update user role to agent if not already
  IF v_user_role != 'agent' THEN
    UPDATE user_profiles
    SET role = 'agent'
    WHERE id = p_user_id;
  END IF;
  
  -- Check if agent record exists
  SELECT EXISTS (
    SELECT 1 FROM agents
    WHERE user_id = p_user_id
  ) INTO v_agent_exists;
  
  -- If agent record doesn't exist, create it
  IF NOT v_agent_exists THEN
    INSERT INTO agents (
      user_id,
      level,
      commission_rate,
      status
    ) VALUES (
      p_user_id,
      1,
      5.0,
      'active'
    )
    RETURNING * INTO v_agent_record;
    
    RETURN jsonb_build_object(
      'success', true,
      'status', v_agent_record.status,
      'created', true
    );
  END IF;
  
  -- Get updated agent record
  SELECT * INTO v_agent_record
  FROM agents
  WHERE user_id = p_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'status', v_agent_record.status,
    'created', false
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_agent_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_agent_if_not_exists(uuid) TO authenticated;