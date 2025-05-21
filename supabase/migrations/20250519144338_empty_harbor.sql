/*
  # Create Admin User
  
  1. Changes
    - Create admin user if not exists
    - Update existing user to admin role
    - Handle profile creation/update properly
*/

DO $$
DECLARE
  v_user_id uuid;
  v_email text := 'admin@cc.com';
  v_profile_exists boolean;
BEGIN
  -- Check if user exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_email;
  
  -- Create or update user
  IF v_user_id IS NULL THEN
    -- Create new user
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
      v_email,
      crypt('123456', gen_salt('bf')),
      NOW(),
      NOW(),
      NOW(),
      jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'admin'
      ),
      jsonb_build_object(
        'role', 'admin'
      ),
      NOW(),
      NOW(),
      '',
      '',
      '',
      ''
    ) RETURNING id INTO v_user_id;
  ELSE
    -- Update existing user
    UPDATE auth.users
    SET 
      raw_app_meta_data = jsonb_build_object(
        'provider', 'email',
        'providers', ARRAY['email'],
        'role', 'admin'
      ),
      raw_user_meta_data = jsonb_build_object(
        'role', 'admin'
      ),
      updated_at = NOW()
    WHERE id = v_user_id;
  END IF;

  -- Check if profile exists
  SELECT EXISTS (
    SELECT 1 FROM user_profiles WHERE id = v_user_id
  ) INTO v_profile_exists;

  -- Create or update profile
  IF v_profile_exists THEN
    UPDATE user_profiles
    SET 
      role = 'admin',
      updated_at = NOW()
    WHERE id = v_user_id;
  ELSE
    INSERT INTO user_profiles (
      id,
      username,
      role,
      created_at,
      updated_at
    ) VALUES (
      v_user_id,
      'Admin',
      'admin',
      NOW(),
      NOW()
    );
  END IF;
END $$;