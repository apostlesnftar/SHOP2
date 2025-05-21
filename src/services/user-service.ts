import { supabase } from '../lib/supabase';
import { User } from '../types';

// Create admin user
export const createAdmin = async (email: string, password: string, username: string) => {
  try {
    // Use the Supabase admin API to create a user
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Auto-confirm email
      user_metadata: { username },
    });
    
    if (error) throw error;
    
    if (data.user) {
      // Update the user's role to admin
      const { error: updateError } = await supabase
        .from('user_profiles')
        .update({ role: 'admin', username })
        .eq('id', data.user.id);
      
      if (updateError) throw updateError;
    }
    
    return data.user;
  } catch (error) {
    console.error('Error creating admin user:', error);
    throw error;
  }
};

// Create agent user
export const createAgent = async (
  email: string, 
  password: string, 
  username: string,
  parentAgentId?: string,
) => {
  try {
    // Create user with Supabase auth
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username },
    });
    
    if (error) throw error;
    
    if (data.user) {
      // Update the user's role to agent
      const { error: updateError } = await supabase
        .from('user_profiles')
        .update({ role: 'agent', username })
        .eq('id', data.user.id);
      
      if (updateError) throw updateError;
      
      // Create agent record
      const { error: agentError } = await supabase
        .from('agents')
        .insert({
          user_id: data.user.id,
          parent_agent_id: parentAgentId || null,
          level: parentAgentId ? 1 : 2, // Level 2 if no parent, Level 1 if has parent
          commission_rate: parentAgentId ? 5 : 10,
        });
      
      if (agentError) throw agentError;
    }
    
    return data.user;
  } catch (error) {
    console.error('Error creating agent user:', error);
    throw error;
  }
};

// Create customer user
export const createCustomer = async (email: string, password: string, username: string) => {
  try {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username },
    });
    
    if (error) throw error;
    
    if (data.user) {
      // Ensure user_profile has correct role
      const { error: updateError } = await supabase
        .from('user_profiles')
        .update({ username })
        .eq('id', data.user.id);
      
      if (updateError) throw updateError;
    }
    
    return data.user;
  } catch (error) {
    console.error('Error creating customer user:', error);
    throw error;
  }
};

// Get all users with profiles
export const getAllUsers = async (): Promise<User[]> => {
  const { data, error } = await supabase
    .from('user_profiles')
    .select('*');
  
  if (error) throw error;
  
  return (data || []).map(profile => ({
    id: profile.id,
    username: profile.username || '',
    email: '',  // Email not accessible from profiles for privacy
    fullName: profile.full_name || undefined,
    profileImage: profile.profile_image || undefined,
    role: profile.role as 'customer' | 'agent' | 'admin',
    createdAt: profile.created_at
  }));
};

// Get user by ID
export const getUserById = async (userId: string): Promise<User | null> => {
  const { data, error } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('id', userId)
    .single();
  
  if (error || !data) return null;
  
  return {
    id: data.id,
    username: data.username || '',
    email: '',  // Email not accessible from profiles for privacy
    fullName: data.full_name || undefined,
    profileImage: data.profile_image || undefined,
    role: data.role as 'customer' | 'agent' | 'admin',
    createdAt: data.created_at
  };
};

// Update user profile
export const updateUserProfile = async (
  userId: string,
  profile: {
    username?: string;
    fullName?: string;
    profileImage?: string;
    phone?: string;
  }
) => {
  const { error } = await supabase
    .from('user_profiles')
    .update({
      username: profile.username,
      full_name: profile.fullName,
      profile_image: profile.profileImage,
      phone: profile.phone
    })
    .eq('id', userId);
  
  if (error) throw error;
  
  return true;
};

// Promote user to agent
export const promoteToAgent = async (
  userId: string, 
  parentAgentId?: string
) => {
  // Update user role first
  const { error: roleError } = await supabase
    .from('user_profiles')
    .update({ role: 'agent' })
    .eq('id', userId);
  
  if (roleError) throw roleError;
  
  // The agent record will be created by the database trigger
  // But if we have a parent agent ID, we need to update it
  if (parentAgentId) {
    const { error: agentError } = await supabase
      .from('agents')
      .update({
        parent_agent_id: parentAgentId,
        level: 1, // Level 1 since it has a parent
        commission_rate: 5
      })
      .eq('user_id', userId);
    
    if (agentError) throw agentError;
  }
  
  return true;
};

// Promote user to admin
export const promoteToAdmin = async (userId: string) => {
  const { error } = await supabase
    .from('user_profiles')
    .update({ role: 'admin' })
    .eq('id', userId);
  
  if (error) throw error;
  
  return true;
};