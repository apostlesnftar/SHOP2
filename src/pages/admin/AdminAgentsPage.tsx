import React, { useState, useEffect } from 'react';
import { Users, Search, TrendingUp, DollarSign, UserCheck, AlertCircle, ChevronDown, ChevronUp, Package, Truck, Clock, BarChart3 } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatCurrency, formatDate } from '../../lib/utils';
import { toast } from 'react-hot-toast';

interface Agent {
  userId: string;
  username: string;
  level: number;
  commissionRate: number;
  totalEarnings: number;
  currentBalance: number;
  status: string;
  createdAt: string;
  teamSize: number;
}

interface TeamMember {
  userId: string;
  username: string;
  fullName: string | null;
  level: number;
  commissionRate: number;
  totalEarnings: number;
  currentBalance: number;
  status: string;
  createdAt: string;
}

interface AgentStats {
  totalAgents: number;
  totalEarnings: number;
  activeAgents: number;
  pendingAgents: number;
  processingOrdersCount: number;
  processingOrdersAmount: number;
}

interface AgentOrderStats {
  totalOrders: number;
  totalAmount: number;
  processingOrders: number;
  processingAmount: number;
  completedOrders: number;
  completedAmount: number;
  teamSize: number;
}

interface CommissionSummary {
  commissionRate: number;
  totalCommissions: number;
  pendingCommissions: number;
  paidCommissions: number;
  recentCommissions: Array<{
    id: string;
    orderId: string;
    orderNumber: string;
    amount: number;
    status: string;
    createdAt: string;
    paidAt?: string;
  }>;
}

const AdminAgentsPage = () => {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [showTeamModal, setShowTeamModal] = useState(false);
  const [showOrderStatsModal, setShowOrderStatsModal] = useState(false);
  const [showCommissionModal, setShowCommissionModal] = useState(false);
  const [showWalletModal, setShowWalletModal] = useState(false);
  const [selectedAgent, setSelectedAgent] = useState<Agent | null>(null);
  const [teamMembers, setTeamMembers] = useState<TeamMember[]>([]);
  const [agentStats, setAgentStats] = useState<AgentStats>({
    totalAgents: 0,
    totalEarnings: 0,
    activeAgents: 0,
    pendingAgents: 0,
    processingOrdersCount: 0,
    processingOrdersAmount: 0
  });
  const [agentOrderStats, setAgentOrderStats] = useState<AgentOrderStats>({
    totalOrders: 0,
    totalAmount: 0,
    processingOrders: 0,
    processingAmount: 0,
    completedOrders: 0,
    completedAmount: 0,
    teamSize: 0
  });
  const [commissionSummary, setCommissionSummary] = useState<CommissionSummary>({
    commissionRate: 0,
    totalCommissions: 0,
    pendingCommissions: 0,
    paidCommissions: 0,
    recentCommissions: []
  });
  const [walletAction, setWalletAction] = useState<'add' | 'subtract'>('add');
  const [walletAmount, setWalletAmount] = useState('');
  const [walletNotes, setWalletNotes] = useState('');
  const [isProcessingWallet, setIsProcessingWallet] = useState(false);
  const [newAgentData, setNewAgentData] = useState({
    email: '',
    commissionRate: '5',
    parentAgentId: ''
  });
  const [isLoadingTeam, setIsLoadingTeam] = useState(false);
  const [isLoadingStats, setIsLoadingStats] = useState(false);
  const [isLoadingCommissions, setIsLoadingCommissions] = useState(false);

  useEffect(() => {
    fetchAgents();
    fetchAgentStats();
  }, []);

  const fetchAgents = async () => {
    try {
      setIsLoading(true);

      // Get all agents with their profile info
      const { data: agentsData, error: agentsError } = await supabase
        .from('agents')
        .select(`
          user_id,
          level,
          commission_rate,
          total_earnings,
          current_balance,
          status,
          created_at,
          user_profiles:user_profiles!agents_user_id_user_profiles_fkey (
            username
          )
        `);

      if (agentsError) throw agentsError;

      // Get team sizes using a count of agents with each parent_agent_id
      const { data: teamSizesData, error: teamSizesError } = await supabase.rpc(
        'count_team_members_by_parent',
        {}
      );

      if (teamSizesError) throw teamSizesError;

      // Create a map of parent_agent_id to team size
      const teamSizes = (teamSizesData || []).reduce((acc, curr) => {
        acc[curr.parent_agent_id] = parseInt(curr.count || 0);
        return acc;
      }, {} as Record<string, number>);

      const formattedAgents = agentsData?.map(agent => ({
        userId: agent.user_id,
        username: agent.user_profiles?.username || 'N/A',
        level: agent.level,
        commissionRate: agent.commission_rate,
        totalEarnings: agent.total_earnings,
        currentBalance: agent.current_balance,
        status: agent.status,
        createdAt: agent.created_at,
        teamSize: teamSizes[agent.user_id] || 0
      })) || [];

      setAgents(formattedAgents);
    } catch (error) {
      console.error('Error fetching agents:', error);
      toast.error('Failed to load agents');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddAgent = async () => {
    try {
      // First get the user ID from user_profiles table using email
      const { data: userData, error: userError } = await supabase
        .from('user_profiles')
        .select('id')
        .eq('email', newAgentData.email)
        .single();

      if (userError) throw userError;
      
      if (!userData) {
        toast.error('User not found with this email');
        return;
      }

      // Update the user's role in user_profiles
      const { error: profileError } = await supabase
        .from('user_profiles')
        .update({ role: 'agent' })
        .eq('id', userData.id);

      if (profileError) throw profileError;

      // The agent record will be created automatically by the trigger
      // We just need to update the commission rate and parent if provided
      const { error: agentError } = await supabase
        .from('agents')
        .update({
          commission_rate: parseFloat(newAgentData.commissionRate),
          parent_agent_id: newAgentData.parentAgentId || null
        })
        .eq('user_id', userData.id);

      if (agentError) throw agentError;

      toast.success('Agent created successfully');
      setShowAddModal(false);
      setNewAgentData({
        email: '',
        commissionRate: '5',
        parentAgentId: ''
      });
      fetchAgents();
    } catch (error) {
      console.error('Error creating agent:', error);
      toast.error('Failed to create agent');
    }
  };

  const fetchAgentStats = async () => {
    try {
      // Get total earnings
      const { data: earningsData, error: earningsError } = await supabase
        .from('agents')
        .select('total_earnings, status');
      
      if (earningsError) throw earningsError;

      // Get processing orders stats
      const { data: processingStats, error: processingError } = await supabase
        .rpc('get_processing_orders_stats');
      
      if (processingError) throw processingError;

      const totalEarnings = earningsData?.reduce((sum, agent) => sum + agent.total_earnings, 0) || 0;
      const activeAgents = earningsData?.filter(agent => agent.status === 'active').length || 0;
      const pendingAgents = earningsData?.filter(agent => agent.status === 'pending').length || 0;

      setAgentStats({
        totalAgents: earningsData?.length || 0,
        totalEarnings,
        activeAgents,
        pendingAgents,
        processingOrdersCount: processingStats?.count || 0,
        processingOrdersAmount: processingStats?.total || 0
      });
    } catch (error) {
      console.error('Error fetching agent stats:', error);
    }
  };

  const fetchAgentTeam = async (agentId: string) => {
    try {
      setIsLoadingTeam(true);
      const { data, error } = await supabase
        .rpc('get_agent_team_members', {
          p_agent_id: agentId
        });

      if (error) throw error;

      const formattedTeam = data?.map(member => ({
        userId: member.user_id,
        username: member.username || 'N/A',
        fullName: member.full_name,
        level: member.level,
        commissionRate: member.commission_rate,
        totalEarnings: member.total_earnings,
        currentBalance: member.current_balance,
        status: member.status,
        createdAt: member.created_at
      })) || [];

      setTeamMembers(formattedTeam);
    } catch (error) {
      console.error('Error fetching agent team:', error);
      toast.error('Failed to load team members');
    } finally {
      setIsLoadingTeam(false);
    }
  };

  const fetchAgentOrderStats = async (agentId: string) => {
    try {
      setIsLoadingStats(true);
      // Get all orders associated with this agent and their team
      const { data, error } = await supabase.rpc('get_agent_team_stats', {
        p_agent_id: agentId
      });

      if (error) throw error;

      if (data && data.success) {
        setAgentOrderStats({
          totalOrders: data.total_orders || 0,
          totalAmount: data.total_amount || 0,
          processingOrders: data.processing_orders || 0,
          processingAmount: data.processing_amount || 0,
          completedOrders: data.completed_orders || 0,
          completedAmount: data.completed_amount || 0,
          teamSize: data.team_size || 0
        });
      }
    } catch (error) {
      console.error('Error fetching agent order stats:', error);
      toast.error('Failed to load order statistics');
    } finally {
      setIsLoadingStats(false);
    }
  };

  const fetchAgentCommissions = async (agentId: string) => {
    try {
      setIsLoadingCommissions(true);
      const { data, error } = await supabase.rpc('get_agent_commission_summary', {
        p_agent_id: agentId
      });

      if (error) throw error;

      if (data && data.success) {
        setCommissionSummary({
          commissionRate: data.commission_rate || 0,
          totalCommissions: data.total_commissions || 0,
          pendingCommissions: data.pending_commissions || 0,
          paidCommissions: data.paid_commissions || 0,
          recentCommissions: data.recent_commissions || []
        });
      }
    } catch (error) {
      console.error('Error fetching agent commissions:', error);
      toast.error('Failed to load commission data');
    } finally {
      setIsLoadingCommissions(false);
    }
  };

  const handleUpdateStatus = async (userId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('agents')
        .update({ status: newStatus })
        .eq('user_id', userId);

      if (error) throw error;

      toast.success('Agent status updated');
      fetchAgents();
    } catch (error) {
      console.error('Error updating agent status:', error);
      toast.error('Failed to update agent status');
    }
  };

  const handleUpdateCommissionRate = async (userId: string, newRate: number) => {
    try {
      const { error } = await supabase
        .from('agents')
        .update({ commission_rate: newRate })
        .eq('user_id', userId);

      if (error) throw error;

      toast.success('Commission rate updated');
      fetchAgents();
    } catch (error) {
      console.error('Error updating commission rate:', error);
      toast.error('Failed to update commission rate');
    }
  };

  const handleWalletAction = async () => {
    if (!selectedAgent) return;
    
    const amount = parseFloat(walletAmount);
    if (isNaN(amount) || amount <= 0) {
      toast.error('Please enter a valid amount');
      return;
    }
    
    setIsProcessingWallet(true);
    try {
      let result;
      
      if (walletAction === 'add') {
        result = await supabase.rpc('admin_add_agent_funds', {
          p_agent_id: selectedAgent.userId,
          p_amount: amount,
          p_notes: walletNotes || null
        });
      } else {
        result = await supabase.rpc('admin_subtract_agent_funds', {
          p_agent_id: selectedAgent.userId,
          p_amount: amount,
          p_notes: walletNotes || null
        });
      }
      
      if (result.error) throw result.error;
      
      if (result.data && result.data.success) {
        toast.success(`Successfully ${walletAction === 'add' ? 'added' : 'subtracted'} funds`);
        setShowWalletModal(false);
        setWalletAmount('');
        setWalletNotes('');
        fetchAgents(); // Refresh agent list to show updated balance
      } else {
        throw new Error(result.data?.error || 'Operation failed');
      }
    } catch (error) {
      console.error('Error processing wallet action:', error);
      toast.error(error instanceof Error ? error.message : 'Failed to process wallet action');
    } finally {
      setIsProcessingWallet(false);
    }
  };

  const handleViewTeam = (agent: Agent) => {
    setSelectedAgent(agent);
    fetchAgentTeam(agent.userId);
    setShowTeamModal(true);
  };

  const handleViewOrderStats = (agent: Agent) => {
    setSelectedAgent(agent);
    fetchAgentOrderStats(agent.userId);
    setShowOrderStatsModal(true);
  };

  const handleViewCommissions = (agent: Agent) => {
    setSelectedAgent(agent);
    fetchAgentCommissions(agent.userId);
    setShowCommissionModal(true);
  };

  const handleManageWallet = (agent: Agent, action: 'add' | 'subtract') => {
    setSelectedAgent(agent);
    setWalletAction(action);
    setWalletAmount('');
    setWalletNotes('');
    setShowWalletModal(true);
  };

  const filteredAgents = agents.filter(agent => {
    const matchesSearch = 
      agent.username.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesStatus = statusFilter === 'all' || agent.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="h-24 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Agent Network</h1>
        <Button
          onClick={() => setShowAddModal(true)}
          leftIcon={<UserCheck className="h-5 w-5" />}
        >
          Add Agent
        </Button>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card className="bg-gradient-to-br from-blue-50 to-blue-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <Users className="h-6 w-6 text-blue-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Total Agents</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {agentStats.totalAgents}
            </div>
            <p className="text-sm text-gray-600">
              {agentStats.activeAgents} active, {agentStats.pendingAgents} pending
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-green-50 to-green-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-green-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <DollarSign className="h-6 w-6 text-green-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Total Earnings</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(agentStats.totalEarnings)}
            </div>
            <p className="text-sm text-gray-600">
              Across all agents
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-amber-50 to-amber-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-amber-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <Truck className="h-6 w-6 text-amber-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Processing Orders</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {agentStats.processingOrdersCount}
            </div>
            <p className="text-sm text-gray-600">
              {formatCurrency(agentStats.processingOrdersAmount)}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-purple-50 to-purple-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-purple-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <TrendingUp className="h-6 w-6 text-purple-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Commission Rate</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {agents.length > 0 ? (agents.reduce((sum, agent) => sum + agent.commissionRate, 0) / agents.length).toFixed(1) : 0}%
            </div>
            <p className="text-sm text-gray-600">
              Average rate
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Search and Filter */}
      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
            <Input
              placeholder="Search agents..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              leftIcon={<Search className="h-5 w-5" />}
              className="flex-grow"
            />
            
            <Select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              options={[
                { value: 'all', label: 'All Statuses' },
                { value: 'active', label: 'Active' },
                { value: 'pending', label: 'Pending' },
                { value: 'suspended', label: 'Suspended' },
                { value: 'inactive', label: 'Inactive' }
              ]}
              className="w-full md:w-48"
            />
          </div>
        </CardContent>
      </Card>

      {/* Agents List */}
      <div className="space-y-4">
        {filteredAgents.length === 0 ? (
          <Card className="p-12 text-center">
            <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 mb-2">No agents found</h2>
            <p className="text-gray-600 mb-6">
              {searchQuery || statusFilter !== 'all'
                ? "No agents match your search criteria"
                : "There are no agents in the system yet"}
            </p>
            <Button
              onClick={() => setShowAddModal(true)}
              leftIcon={<UserCheck className="h-5 w-5" />}
            >
              Add Agent
            </Button>
          </Card>
        ) : (
          filteredAgents.map((agent) => (
            <Card key={agent.userId} className="overflow-hidden hover:shadow-md transition-shadow">
              <CardContent className="p-0">
                <div className="p-6">
                  <div className="flex flex-col md:flex-row md:items-center justify-between">
                    <div className="flex items-center mb-4 md:mb-0">
                      <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-4">
                        <UserCheck className="h-6 w-6" />
                      </div>
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900">{agent.username}</h3>
                        <div className="flex items-center mt-1">
                          <Badge
                            variant={
                              agent.status === 'active' ? 'success' :
                              agent.status === 'pending' ? 'warning' :
                              agent.status === 'suspended' ? 'danger' : 'secondary'
                            }
                            size="sm"
                            className="capitalize mr-2"
                          >
                            {agent.status}
                          </Badge>
                          <span className="text-xs text-gray-500">
                            Level {agent.level} • {formatDate(agent.createdAt)}
                          </span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex flex-wrap gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleViewTeam(agent)}
                      >
                        Team ({agent.teamSize})
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleViewOrderStats(agent)}
                      >
                        Order Stats
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleViewCommissions(agent)}
                      >
                        Commissions
                      </Button>
                      <div className="flex gap-1">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleManageWallet(agent, 'add')}
                          className="text-green-600 hover:text-green-700 hover:bg-green-50"
                        >
                          + Add Funds
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleManageWallet(agent, 'subtract')}
                          className="text-red-600 hover:text-red-700 hover:bg-red-50"
                        >
                          - Remove Funds
                        </Button>
                      </div>
                      <Select
                        value={agent.status}
                        onChange={(e) => handleUpdateStatus(agent.userId, e.target.value)}
                        options={[
                          { value: 'active', label: 'Active' },
                          { value: 'pending', label: 'Pending' },
                          { value: 'suspended', label: 'Suspended' },
                          { value: 'inactive', label: 'Inactive' }
                        ]}
                        className="w-32"
                      />
                    </div>
                  </div>
                </div>
                
                <div className="border-t border-gray-200 bg-gray-50 p-4">
                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                      <p className="text-sm text-gray-500">Commission Rate</p>
                      <div className="flex items-center mt-1">
                        <input
                          type="number"
                          min="0"
                          max="100"
                          value={agent.commissionRate}
                          onChange={(e) => handleUpdateCommissionRate(agent.userId, parseFloat(e.target.value))}
                          className="w-16 px-2 py-1 border border-gray-300 rounded mr-2"
                        />
                        <span className="text-gray-700">%</span>
                      </div>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500">Total Earnings</p>
                      <p className="font-semibold text-gray-900">{formatCurrency(agent.totalEarnings)}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500">Current Balance</p>
                      <p className="font-semibold text-gray-900">{formatCurrency(agent.currentBalance)}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500">Team Size</p>
                      <p className="font-semibold text-gray-900">{agent.teamSize} members</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Add Agent Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle>Add New Agent</CardTitle>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                <Input
                  label="Email"
                  type="email"
                  value={newAgentData.email}
                  onChange={(e) => setNewAgentData({ ...newAgentData, email: e.target.value })}
                  placeholder="Enter user email"
                  required
                />
                
                <Input
                  label="Commission Rate (%)"
                  type="number"
                  min="0"
                  max="100"
                  value={newAgentData.commissionRate}
                  onChange={(e) => setNewAgentData({ ...newAgentData, commissionRate: e.target.value })}
                  required
                />
                
                <Select
                  label="Parent Agent (Optional)"
                  value={newAgentData.parentAgentId}
                  onChange={(e) => setNewAgentData({ ...newAgentData, parentAgentId: e.target.value })}
                  options={[
                    { value: '', label: 'None (Top Level)' },
                    ...agents
                      .filter(a => a.status === 'active')
                      .map(a => ({ value: a.userId, label: a.username }))
                  ]}
                />
                
                <div className="flex justify-end gap-2 mt-6">
                  <Button
                    variant="outline"
                    onClick={() => setShowAddModal(false)}
                  >
                    Cancel
                  </Button>
                  <Button onClick={handleAddAgent}>
                    Add Agent
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* View Team Modal */}
      {showTeamModal && selectedAgent &&
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-4xl max-h-[80vh] overflow-hidden flex flex-col">
            <CardHeader>
              <div className="flex justify-between items-center">
                <CardTitle>Team Members for {selectedAgent.username}</CardTitle>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowTeamModal(false)}
                >
                  Close
                </Button>
              </div>
            </CardHeader>
            <CardContent className="p-6 overflow-auto flex-grow">
              {isLoadingTeam ? (
                <div className="flex justify-center items-center h-40">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                </div>
              ) : teamMembers.length === 0 ? (
                <div className="text-center py-8">
                  <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">No Team Members</h3>
                  <p className="text-gray-600">This agent doesn't have any team members yet.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {teamMembers.map((member) => (
                    <Card key={member.userId} className="overflow-hidden hover:shadow-sm transition-shadow">
                      <CardContent className="p-4">
                        <div className="flex flex-col md:flex-row md:items-center justify-between">
                          <div className="flex items-center mb-4 md:mb-0">
                            <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-3">
                              <UserCheck className="h-5 w-5" />
                            </div>
                            <div>
                              <h3 className="font-semibold text-gray-900">{member.username}</h3>
                              <p className="text-sm text-gray-500">{member.fullName || 'No name provided'}</p>
                              <div className="flex items-center mt-1">
                                <Badge
                                  variant={
                                    member.status === 'active' ? 'success' :
                                    member.status === 'pending' ? 'warning' :
                                    member.status === 'suspended' ? 'danger' : 'secondary'
                                  }
                                  size="sm"
                                  className="capitalize mr-2"
                                >
                                  {member.status}
                                </Badge>
                                <span className="text-xs text-gray-500">
                                  Level {member.level} • Joined {formatDate(member.createdAt)}
                                </span>
                              </div>
                            </div>
                          </div>
                          
                          <div className="flex items-center space-x-4">
                            <div>
                              <p className="text-xs text-gray-500">Commission Rate</p>
                              <p className="font-semibold text-gray-900">{member.commissionRate}%</p>
                            </div>
                            <div>
                              <p className="text-xs text-gray-500">Total Earnings</p>
                              <p className="font-semibold text-gray-900">{formatCurrency(member.totalEarnings)}</p>
                            </div>
                            <div>
                              <p className="text-xs text-gray-500">Current Balance</p>
                              <p className="font-semibold text-gray-900">{formatCurrency(member.currentBalance)}</p>
                            </div>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      }

      {/* View Order Stats Modal */}
      {showOrderStatsModal && selectedAgent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-4xl max-h-[80vh] overflow-hidden flex flex-col">
            <CardHeader>
              <div className="flex justify-between items-center">
                <CardTitle>Order Statistics for {selectedAgent.username} and Team</CardTitle>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowOrderStatsModal(false)}
                >
                  Close
                </Button>
              </div>
            </CardHeader>
            <CardContent className="p-6 overflow-auto flex-grow">
              {isLoadingStats ? (
                <div className="flex justify-center items-center h-40">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                </div>
              ) : (
                <>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                    <Card className="bg-gradient-to-br from-blue-50 to-blue-100">
                      <CardContent className="p-6">
                        <div className="flex items-center justify-between mb-4">
                          <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-full flex items-center justify-center">
                            <Package className="h-6 w-6 text-blue-600" />
                          </div>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900">Total Orders</h3>
                        <div className="text-3xl font-bold text-gray-900 mb-1">
                          {agentOrderStats.totalOrders}
                        </div>
                        <p className="text-sm text-gray-600">
                          {formatCurrency(agentOrderStats.totalAmount)}
                        </p>
                      </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-amber-50 to-amber-100">
                      <CardContent className="p-6">
                        <div className="flex items-center justify-between mb-4">
                          <div className="w-12 h-12 bg-amber-500 bg-opacity-20 rounded-full flex items-center justify-center">
                            <Truck className="h-6 w-6 text-amber-600" />
                          </div>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900">Processing</h3>
                        <div className="text-3xl font-bold text-gray-900 mb-1">
                          {agentOrderStats.processingOrders}
                        </div>
                        <p className="text-sm text-gray-600">
                          {formatCurrency(agentOrderStats.processingAmount)}
                        </p>
                      </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-green-50 to-green-100">
                      <CardContent className="p-6">
                        <div className="flex items-center justify-between mb-4">
                          <div className="w-12 h-12 bg-green-500 bg-opacity-20 rounded-full flex items-center justify-center">
                            <TrendingUp className="h-6 w-6 text-green-600" />
                          </div>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900">Completed</h3>
                        <div className="text-3xl font-bold text-gray-900 mb-1">
                          {agentOrderStats.completedOrders}
                        </div>
                        <p className="text-sm text-gray-600">
                          {formatCurrency(agentOrderStats.completedAmount)}
                        </p>
                      </CardContent>
                    </Card>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                    <Card>
                      <CardHeader>
                        <CardTitle>Team Overview</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <div className="space-y-4">
                          <div className="flex justify-between items-center">
                            <span className="text-gray-600">Team Size:</span>
                            <span className="font-semibold">{agentOrderStats.teamSize} members</span>
                          </div>
                          <div className="flex justify-between items-center">
                            <span className="text-gray-600">Average Commission Rate:</span>
                            <span className="font-semibold">{selectedAgent.commissionRate}%</span>
                          </div>
                          <div className="flex justify-between items-center">
                            <span className="text-gray-600">Estimated Commission:</span>
                            <span className="font-semibold text-green-600">
                              {formatCurrency(agentOrderStats.totalAmount * (selectedAgent.commissionRate / 100))}
                            </span>
                          </div>
                        </div>
                      </CardContent>
                    </Card>

                    <Card>
                      <CardHeader>
                        <CardTitle>Order Breakdown</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <div className="space-y-4">
                          <div className="flex justify-between items-center">
                            <span className="text-gray-600">Processing Orders:</span>
                            <div className="text-right">
                              <div className="font-semibold">{agentOrderStats.processingOrders} orders</div>
                              <div className="text-sm text-amber-600">{formatCurrency(agentOrderStats.processingAmount)}</div>
                            </div>
                          </div>
                          <div className="flex justify-between items-center">
                            <span className="text-gray-600">Completed Orders:</span>
                            <div className="text-right">
                              <div className="font-semibold">{agentOrderStats.completedOrders} orders</div>
                              <div className="text-sm text-green-600">{formatCurrency(agentOrderStats.completedAmount)}</div>
                            </div>
                          </div>
                          <div className="flex justify-between items-center pt-2 border-t border-gray-200">
                            <span className="text-gray-600">Total Orders:</span>
                            <div className="text-right">
                              <div className="font-semibold">{agentOrderStats.totalOrders} orders</div>
                              <div className="text-sm font-medium">{formatCurrency(agentOrderStats.totalAmount)}</div>
                            </div>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  </div>

                  <Card>
                    <CardHeader>
                      <CardTitle>Performance Summary</CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-4">
                        <p className="text-gray-600">
                          This agent and their team have generated a total of <span className="font-semibold">{formatCurrency(agentOrderStats.totalAmount)}</span> in sales 
                          across <span className="font-semibold">{agentOrderStats.totalOrders}</span> orders.
                        </p>
                        <p className="text-gray-600">
                          Currently, there are <span className="font-semibold text-amber-600">{agentOrderStats.processingOrders} orders in processing</span> with 
                          a value of <span className="font-semibold text-amber-600">{formatCurrency(agentOrderStats.processingAmount)}</span>.
                        </p>
                        <p className="text-gray-600">
                          Based on the current commission rate of <span className="font-semibold">{selectedAgent.commissionRate}%</span>, 
                          the estimated commission on all orders is <span className="font-semibold text-green-600">
                            {formatCurrency(agentOrderStats.totalAmount * (selectedAgent.commissionRate / 100))}
                          </span>.
                        </p>
                      </div>
                    </CardContent>
                  </Card>
                </>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* View Commission Modal */}
      {showCommissionModal && selectedAgent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-4xl max-h-[80vh] overflow-hidden flex flex-col">
            <CardHeader>
              <div className="flex justify-between items-center">
                <CardTitle>Commission Details for {selectedAgent.username}</CardTitle>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowCommissionModal(false)}
                >
                  Close
                </Button>
              </div>
            </CardHeader>
            <CardContent className="p-6 overflow-auto flex-grow">
              {isLoadingCommissions ? (
                <div className="flex justify-center items-center h-40">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                </div>
              ) : (
                <>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                    <Card className="bg-gradient-to-br from-blue-50 to-blue-100">
                      <CardContent className="p-6">
                        <div className="flex items-center justify-between mb-4">
                          <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-full flex items-center justify-center">
                            <DollarSign className="h-6 w-6 text-blue-600" />
                          </div>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900">Total Commissions</h3>
                        <div className="text-3xl font-bold text-gray-900 mb-1">
                          {formatCurrency(commissionSummary.totalCommissions)}
                        </div>
                        <p className="text-sm text-gray-600">
                          Lifetime earnings
                        </p>
                      </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-amber-50 to-amber-100">
                      <CardContent className="p-6">
                        <div className="flex items-center justify-between mb-4">
                          <div className="w-12 h-12 bg-amber-500 bg-opacity-20 rounded-full flex items-center justify-center">
                            <Clock className="h-6 w-6 text-amber-600" />
                          </div>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900">Pending</h3>
                        <div className="text-3xl font-bold text-gray-900 mb-1">
                          {formatCurrency(commissionSummary.pendingCommissions)}
                        </div>
                        <p className="text-sm text-gray-600">
                          Awaiting payment
                        </p>
                      </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-green-50 to-green-100">
                      <CardContent className="p-6">
                        <div className="flex items-center justify-between mb-4">
                          <div className="w-12 h-12 bg-green-500 bg-opacity-20 rounded-full flex items-center justify-center">
                            <BarChart3 className="h-6 w-6 text-green-600" />
                          </div>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900">Paid</h3>
                        <div className="text-3xl font-bold text-gray-900 mb-1">
                          {formatCurrency(commissionSummary.paidCommissions)}
                        </div>
                        <p className="text-sm text-gray-600">
                          Already paid out
                        </p>
                      </CardContent>
                    </Card>
                  </div>

                  <Card>
                    <CardHeader>
                      <CardTitle>Recent Commissions</CardTitle>
                    </CardHeader>
                    <CardContent>
                      {commissionSummary.recentCommissions && commissionSummary.recentCommissions.length > 0 ? (
                        <div className="overflow-x-auto">
                          <table className="w-full min-w-[600px] text-sm">
                            <thead>
                              <tr className="text-left border-b border-gray-200">
                                <th className="pb-3 font-medium text-gray-900">Order</th>
                                <th className="pb-3 font-medium text-gray-900">Date</th>
                                <th className="pb-3 font-medium text-gray-900">Amount</th>
                                <th className="pb-3 font-medium text-gray-900">Status</th>
                                <th className="pb-3 font-medium text-gray-900">Paid Date</th>
                              </tr>
                            </thead>
                            <tbody>
                              {commissionSummary.recentCommissions.map((commission) => (
                                <tr key={commission.id} className="border-b border-gray-200">
                                  <td className="py-4 text-gray-900">#{commission.orderNumber}</td>
                                  <td className="py-4 text-gray-600">
                                    {formatDate(commission.createdAt)}
                                  </td>
                                  <td className="py-4 font-medium text-gray-900">
                                    {formatCurrency(commission.amount)}
                                  </td>
                                  <td className="py-4">
                                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                      commission.status === 'paid' ? 'bg-green-100 text-green-800' :
                                      commission.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                                      'bg-red-100 text-red-800'
                                    }`}>
                                      {commission.status.charAt(0).toUpperCase() + commission.status.slice(1)}
                                    </span>
                                  </td>
                                  <td className="py-4 text-gray-600">
                                    {commission.paidAt ? formatDate(commission.paidAt) : '-'}
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      ) : (
                        <div className="text-center py-6">
                          <p className="text-gray-500">No commission records found</p>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                </>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* Wallet Management Modal */}
      {showWalletModal && selectedAgent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-md">
            <CardHeader>
              <div className="flex justify-between items-center">
                <CardTitle>
                  {walletAction === 'add' ? 'Add Funds to' : 'Remove Funds from'} {selectedAgent.username}'s Wallet
                </CardTitle>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowWalletModal(false)}
                >
                  Close
                </Button>
              </div>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                <div className="bg-gray-50 p-4 rounded-lg mb-4">
                  <div className="flex justify-between items-center">
                    <span className="text-gray-600">Current Balance:</span>
                    <span className="font-semibold text-gray-900">{formatCurrency(selectedAgent.currentBalance)}</span>
                  </div>
                  <div className="flex justify-between items-center mt-2">
                    <span className="text-gray-600">Total Earnings:</span>
                    <span className="font-semibold text-gray-900">{formatCurrency(selectedAgent.totalEarnings)}</span>
                  </div>
                </div>

                <Input
                  label="Amount"
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={walletAmount}
                  onChange={(e) => setWalletAmount(e.target.value)}
                  placeholder="Enter amount"
                  required
                />

                <Input
                  label="Notes (Optional)"
                  value={walletNotes}
                  onChange={(e) => setWalletNotes(e.target.value)}
                  placeholder="Add a note for this transaction"
                />

                {walletAction === 'subtract' && (
                  <div className="bg-amber-50 p-4 rounded-lg border border-amber-200">
                    <div className="flex items-start">
                      <AlertCircle className="h-5 w-5 text-amber-500 mt-0.5 mr-3" />
                      <div>
                        <h4 className="font-medium text-amber-800 mb-1">Important Note</h4>
                        <p className="text-sm text-amber-700">
                          Removing funds will reduce the agent's current balance. Make sure you have a valid reason for this action.
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                <div className="flex justify-end gap-2 mt-6">
                  <Button
                    variant="outline"
                    onClick={() => setShowWalletModal(false)}
                    disabled={isProcessingWallet}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleWalletAction}
                    isLoading={isProcessingWallet}
                    variant={walletAction === 'add' ? 'primary' : 'danger'}
                  >
                    {walletAction === 'add' ? 'Add Funds' : 'Remove Funds'}
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default AdminAgentsPage;