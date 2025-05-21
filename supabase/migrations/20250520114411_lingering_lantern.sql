/*
  # Add foreign key relationship between agents and user_profiles tables

  1. Changes
    - Add foreign key relationship between agents.user_id and user_profiles.id
    - Add indexes to improve query performance
    - Update RLS policies to allow proper access

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control between agents and user profiles
*/

-- Add foreign key relationship between agents and user_profiles
ALTER TABLE agents
ADD CONSTRAINT agents_user_id_user_profiles_fkey
FOREIGN KEY (user_id) REFERENCES user_profiles(id)
ON DELETE CASCADE;

-- Add index to improve join performance
CREATE INDEX IF NOT EXISTS idx_agents_user_id ON agents(user_id);

-- Update the agents table RLS policies to include user_profiles access
CREATE POLICY "Agents can view their own profile and team profiles"
ON user_profiles
FOR SELECT
TO public
USING (
  id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM agents
    WHERE agents.user_id = auth.uid()
    AND (
      agents.user_id = user_profiles.id
      OR EXISTS (
        SELECT 1 FROM agents team_member
        WHERE team_member.parent_agent_id = agents.user_id
        AND team_member.user_id = user_profiles.id
      )
    )
  )
);