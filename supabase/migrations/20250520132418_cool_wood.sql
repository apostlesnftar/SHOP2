/*
  # Add bind_user_to_agent_team function
  
  1. New Functions
    - `bind_user_to_agent_team`: Binds an existing user to an agent's team by username
      - Allows adding existing users to an agent's team
      - Updates user role to agent if needed
      - Sets proper parent-child relationship
      - Handles commission rate setting
*/

-- Function to bind an existing user to an agent's team
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION bind_user_to_agent_team(uuid, text, numeric) TO authenticated;