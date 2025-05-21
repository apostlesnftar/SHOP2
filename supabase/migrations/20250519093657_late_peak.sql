/*
  # Add Default Users
  
  1. User Creation
    - Create admin, agent, and customer user accounts
    - Set up proper relationships
*/

-- We can't directly create users in auth.users via SQL
-- This is a placeholder to indicate we'll create these users via Supabase API

-- Update template user references
UPDATE addresses SET user_id = (SELECT id FROM auth.users WHERE email = 'admin@example.com' LIMIT 1) WHERE user_id = '00000000-0000-0000-0000-000000000000';
UPDATE orders SET user_id = (SELECT id FROM auth.users WHERE email = 'user@example.com' LIMIT 1) WHERE user_id = '00000000-0000-0000-0000-000000000000';
UPDATE agents SET user_id = (SELECT id FROM auth.users WHERE email = 'agent@example.com' LIMIT 1) WHERE user_id = '00000000-0000-0000-0000-000000000000';
UPDATE commissions SET agent_id = (SELECT id FROM auth.users WHERE email = 'agent@example.com' LIMIT 1) WHERE agent_id = '00000000-0000-0000-0000-000000000000';

-- Update user profiles
UPDATE user_profiles 
SET role = 'admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@example.com');

UPDATE user_profiles 
SET role = 'agent'
WHERE id = (SELECT id FROM auth.users WHERE email = 'agent@example.com');

UPDATE user_profiles 
SET role = 'customer'
WHERE id = (SELECT id FROM auth.users WHERE email = 'user@example.com');