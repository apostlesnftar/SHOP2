import { supabase } from '../lib/supabase';
import { Agent, Commission } from '../types';

// Get agent by user ID
export const getAgentByUserId = async (userId: string): Promise<Agent | null> => {
  const { data, error } = await supabase
    .from('agents')
    .select('*')
    .eq('user_id', userId)
    .single();
  
  if (error || !data) return null;
  
  return {
    userId: data.user_id,
    level: data.level,
    parentAgentId: data.parent_agent_id || undefined,
    commissionRate: data.commission_rate,
    totalEarnings: data.total_earnings,
    currentBalance: data.current_balance,
    status: data.status as 'pending' | 'active' | 'suspended' | 'inactive',
    createdAt: data.created_at,
    updatedAt: data.updated_at
  };
};

// Get agent commissions
export const getAgentCommissions = async (agentId: string): Promise<Commission[]> => {
  const { data, error } = await supabase
    .from('commissions')
    .select('*')
    .eq('agent_id', agentId)
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(commission => ({
    id: commission.id,
    agentId: commission.agent_id,
    orderId: commission.order_id,
    amount: commission.amount,
    status: commission.status as 'pending' | 'paid' | 'cancelled',
    createdAt: commission.created_at,
    paidAt: commission.paid_at
  }));
};

// Get agent team members (users who were referred by this agent)
export const getAgentTeam = async (agentId: string) => {
  const { data, error } = await supabase
    .from('agents')
    .select(`
      user_id,
      level,
      commission_rate,
      total_earnings,
      status,
      created_at,
      user:user_profiles(*)
    `)
    .eq('parent_agent_id', agentId);
  
  if (error) throw error;
  
  return (data || []).map((member: any) => ({
    id: member.user_id,
    name: member.user?.username || member.user?.full_name || 'Unknown User',
    email: '', // Email not accessible from profiles for privacy
    level: member.level,
    joinDate: member.created_at,
    totalSales: 0, // Would need additional query to calculate this
    totalCommission: member.total_earnings,
    status: member.status
  }));
};

// Apply to become an agent
export const applyToBecomeAgent = async (
  userId: string,
  referrerCode?: string
): Promise<Agent> => {
  let parentAgentId = null;
  
  // If a referrer code is provided, find the parent agent
  if (referrerCode) {
    const { data, error } = await supabase
      .from('agents')
      .select('user_id')
      .eq('user_id', referrerCode)
      .single();
    
    if (!error && data) {
      parentAgentId = data.user_id;
    }
  }
  
  // Update user profile to agent role
  const { error: profileError } = await supabase
    .from('user_profiles')
    .update({ role: 'agent' })
    .eq('id', userId);
  
  if (profileError) throw profileError;
  
  // The agent record will be created automatically by the trigger
  // Wait a moment for the trigger to complete
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // If we have a parent agent ID, update the agent record
  if (parentAgentId) {
    const { error: agentError } = await supabase
      .from('agents')
      .update({
        parent_agent_id: parentAgentId,
        level: 1,
        commission_rate: 5
      })
      .eq('user_id', userId);
    
    if (agentError) throw agentError;
  }
  
  // Get the created agent
  const { data: agent, error: getError } = await supabase
    .from('agents')
    .select('*')
    .eq('user_id', userId)
    .single();
  
  if (getError || !agent) throw getError || new Error('Failed to retrieve agent record');
  
  return {
    userId: agent.user_id,
    level: agent.level,
    parentAgentId: agent.parent_agent_id || undefined,
    commissionRate: agent.commission_rate,
    totalEarnings: agent.total_earnings,
    currentBalance: agent.current_balance,
    status: agent.status as 'pending' | 'active' | 'suspended' | 'inactive',
    createdAt: agent.created_at,
    updatedAt: agent.updated_at
  };
};

// Withdraw agent earnings
export const withdrawAgentEarnings = async (
  agentId: string,
  amount: number
): Promise<boolean> => {
  // Get current balance
  const { data: agent, error: getError } = await supabase
    .from('agents')
    .select('current_balance')
    .eq('user_id', agentId)
    .single();
  
  if (getError || !agent) throw getError || new Error('Failed to retrieve agent record');
  
  // Check if enough balance
  if (agent.current_balance < amount) {
    throw new Error('Insufficient balance');
  }
  
  // Update agent balance
  const { error } = await supabase
    .from('agents')
    .update({
      current_balance: agent.current_balance - amount
    })
    .eq('user_id', agentId);
  
  if (error) throw error;
  
  // In a real app, you would also create a withdraw transaction record
  // and handle the actual payment processing
  
  return true;
};