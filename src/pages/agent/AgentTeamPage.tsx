import React, { useState, useEffect } from 'react';
import { Users, UserPlus, Search, TrendingUp, DollarSign, X, Mail, ChevronDown, ChevronUp, UserCheck } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatCurrency, formatDate } from '../../lib/utils';
import { toast } from 'react-hot-toast';
import { v4 as uuidv4 } from 'uuid';
import { useAuthStore } from '../../store/auth-store';

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
  isAgent: boolean;
  orderStats?: {
    totalOrders: number;
    totalAmount: number;
    processingOrders: number;
    processingAmount: number;
    completedOrders: number;
    completedAmount: number;
  };
  expanded?: boolean;
}

const AgentTeamPage: React.FC = () => {
  const { user } = useAuthStore();
  const [teamMembers, setTeamMembers] = useState<TeamMember[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [newTeamMember, setNewTeamMember] = useState({
    username: '',
    commissionRate: '3'
  });
  const [isAddingTeamMember, setIsAddingTeamMember] = useState(false);
  const [teamStats, setTeamStats] = useState({
    teamSize: 0,
    totalEarnings: 0,
    totalOrders: 0,
    totalAmount: 0
  });
  const [referralLink, setReferralLink] = useState('');

  useEffect(() => {
    if (user?.id) {
      fetchTeamMembers();
      fetchTeamStats();
      generateReferralLink();
    }
  }, [user?.id]);

  const generateReferralLink = () => {
    if (user?.id) {
      const baseUrl = window.location.origin;
      setReferralLink(`${baseUrl}/register?ref=${user.id || ''}`);
    }
  };

  const copyReferralLink = async () => {
    try {
      await navigator.clipboard.writeText(referralLink);
      toast.success('Referral link copied to clipboard!');
    } catch (err) {
      toast.error('Failed to copy link');
    }
  };

  const fetchTeamMembers = async () => {
    if (!user?.id) return;
    
    try {
      setIsLoading(true);
      const { data, error } = await supabase
        .rpc('get_agent_team_members', {
        p_agent_id: user.id,
      });

      if (error) throw error;

      const formattedTeam = (data || []).map(member => ({
        userId: member.user_id,
        username: member.username || 'N/A',
        fullName: member.full_name,
        level: member.level,
        commissionRate: member.commission_rate,
        totalEarnings: member.total_earnings,
        currentBalance: member.current_balance,
        isAgent: member.is_agent,
        status: member.status,
        createdAt: member.created_at,
        expanded: false
      }));

      // Sort team members by registration time (newest first)
      const sortedTeamMembers = formattedTeam.sort((a, b) => 
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );
      
      setTeamMembers(sortedTeamMembers);
    } catch (error) {
      console.error('Error fetching team members:', error);
      toast.error('Failed to load team members');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchTeamStats = async () => {
    if (!user?.id) return;
    
    try {
      const { data: statsData, error: statsError } = await supabase.rpc('get_agent_team_stats', {
        p_agent_id: user.id
      });
      
      if (statsError) throw statsError;
      
      if (statsData && statsData.success) {
        setTeamStats({
          teamSize: statsData.team_size || 0, 
          totalEarnings: statsData.total_earnings || 0,
          totalOrders: statsData.total_orders || 0,
          totalAmount: statsData.total_amount || 0
        });
      }
    } catch (error) {
      console.error('Error fetching team stats:', error);
    }
  };

  const fetchMemberOrderStats = async (memberId: string, index: number) => {
    try {
      // Only fetch order stats for agent members
      if (teamMembers[index].isAgent) {        
        const { data, error } = await supabase.rpc('get_agent_team_stats', {
          p_agent_id: memberId 
        });
        
        if (error) throw error;

        if (data && data.success) {
          const updatedMembers = [...teamMembers];
          updatedMembers[index] = {
            ...updatedMembers[index],
            orderStats: {
              totalOrders: data.total_orders,
              totalAmount: data.total_amount,
              processingOrders: data.processing_orders,
              processingAmount: data.processing_amount,
              completedOrders: data.completed_orders,
              completedAmount: data.completed_amount
            }
          };
          setTeamMembers(updatedMembers);
        }
      } else {        
        // For customers, use the customer order stats function
        const { data, error } = await supabase.rpc('get_customer_order_stats', {
          p_customer_id: memberId
        });

        if (error) throw error;

        if (!data.success) {
          throw new Error(data.error || 'Failed to get customer order stats');
        }

        const updatedMembers = [...teamMembers];
        updatedMembers[index] = {
          ...updatedMembers[index],
          orderStats: {
            totalOrders: data.total_orders,
            totalAmount: data.total_amount,
            processingOrders: data.processing_orders,
            processingAmount: data.processing_amount,
            completedOrders: data.completed_orders,
            completedAmount: data.completed_amount
          }
        };
        setTeamMembers(updatedMembers);
      }
    } catch (error) {
      console.error('Error fetching member order stats:', error);
    }
  };

  const handleAddTeamMember = async () => {
    if (!user?.id) return;
    
    if (!newTeamMember.username.trim()) {
      toast.error('Please enter a username');
      return;
    }

    setIsAddingTeamMember(true);
    
    try {
      const { data, error } = await supabase.rpc('bind_user_to_agent_team', {
        p_agent_id: user.id,
        p_username: newTeamMember.username,
        p_commission_rate: parseFloat(newTeamMember.commissionRate)
      });
      
      if (error) {
        throw error;
      }
      
      if (!data.success) {
        throw new Error(data.error || 'Failed to add team member');
      }
      
      toast.success(`User ${newTeamMember.username} added to your team!`);
      setShowAddModal(false);
      setNewTeamMember({
        username: '',
        commissionRate: '3'
      });
      fetchTeamMembers();
      fetchTeamStats();
    } catch (error) {
      console.error('Error adding team member:', error);
      toast.error(error instanceof Error ? error.message : 'Failed to add team member');
    } finally {
      setIsAddingTeamMember(false);
    }
  };

  const handleUpdateCommissionRate = async (userId: string, newRate: number) => {
    try {
      if (isNaN(newRate) || newRate < 0 || newRate > 100) {
        toast.error('Commission rate must be between 0 and 100');
        return;
      }

      const { error } = await supabase
        .from('agents')
        .update({ commission_rate: newRate })
        .eq('user_id', userId);

      if (error) throw error;

      toast.success('Commission rate updated');
      fetchTeamMembers();
    } catch (error) {
      console.error('Error updating commission rate:', error);
      toast.error('Failed to update commission rate');
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
      fetchTeamMembers();
    } catch (error) {
      console.error('Error updating agent status:', error);
      toast.error('Failed to update agent status');
    }
  };

  const toggleMemberExpanded = (index: number) => {
    const updatedMembers = [...teamMembers];
    updatedMembers[index].expanded = !updatedMembers[index].expanded;
    
    if (updatedMembers[index].expanded && !updatedMembers[index].orderStats) {
      fetchMemberOrderStats(updatedMembers[index].userId, index);
    }
    
    setTeamMembers(updatedMembers);
  };

  const filteredTeamMembers = teamMembers.filter(member => {
    const matchesSearch = 
      member.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (member.fullName && member.fullName.toLowerCase().includes(searchQuery.toLowerCase()));
    
    const matchesStatus = statusFilter === 'all' || member.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
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
        <h1 className="text-3xl font-bold text-gray-900">My Team</h1>
        <Button
          onClick={() => setShowAddModal(true)} 
          leftIcon={<UserPlus className="h-5 w-5" />} 
        >
          Add Team Member
        </Button>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <Card className="bg-gradient-to-br from-blue-50 to-blue-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <Users className="h-6 w-6 text-blue-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Team Size</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {teamStats.teamSize}
            </div>
            <p className="text-sm text-gray-600">
              Active team members
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-green-50 to-green-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-green-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <DollarSign className="h-6 w-6 text-green-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Team Earnings</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(teamStats.totalEarnings)}
            </div>
            <p className="text-sm text-gray-600">
              Total team commissions
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-purple-50 to-purple-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-purple-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <TrendingUp className="h-6 w-6 text-purple-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Team Sales</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(teamStats.totalAmount)}
            </div>
            <p className="text-sm text-gray-600">
              {teamStats.totalOrders} orders
            </p>
          </CardContent>
        </Card>
        
        <Card className="lg:col-span-2">
          <CardContent className="p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Your Referral Link</h3>
            <div className="flex flex-col md:flex-row gap-3">
              <div className="flex-grow relative">
                <input
                  type="text"
                  value={referralLink}
                  readOnly
                  className="w-full px-4 py-2 border border-gray-300 rounded-md bg-gray-50"
                />
              </div>
              <Button
                onClick={copyReferralLink}
                className="whitespace-nowrap"
              >
                Copy Link
              </Button>
            </div>
            <p className="mt-3 text-sm text-gray-600">
              Share this link with potential team members. When they register using this link, 
              they'll automatically be added to your team.
            </p>
          </CardContent>
        </Card>
      </div>
      
      <div className="mb-6 flex flex-col sm:flex-row gap-4">
        <Input
          placeholder="Search team members..."
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
      
      <div className="space-y-4">
        {filteredTeamMembers.length === 0 ? (
          <Card className="p-12 text-center">
            <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 mb-2">No team members found</h2>
            <p className="text-gray-600 mb-6">
              {searchQuery || statusFilter !== 'all'
                ? "No team members match your search criteria"
                : "You don't have any team members yet"}
            </p>
            <Button
              onClick={() => setShowAddModal(true)}
              leftIcon={<UserPlus className="h-5 w-5" />}
            >
              Add Team Member
            </Button>
          </Card>
        ) : (
          filteredTeamMembers.map((member, index) => (
            <Card key={member.userId} className="overflow-hidden">
              <CardContent className="p-0">
                <div 
                  className="p-6 cursor-pointer"
                  onClick={() => toggleMemberExpanded(index)}
                >
                  <div className="flex flex-col md:flex-row md:items-center justify-between">
                    <div className="flex items-center mb-4 md:mb-0">
                      <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-4">
                        <UserCheck className="h-6 w-6" />
                      </div>
                      <div>
                        <div className="flex items-center">
                          <h3 className="text-lg font-semibold text-gray-900 mr-2">{member.username}</h3>
                          {member.expanded ? (
                            <ChevronUp className="h-5 w-5 text-gray-500" />
                          ) : (
                            <ChevronDown className="h-5 w-5 text-gray-500" />
                          )}
                        </div>
                        <div className="flex items-center mt-1">
                          <Badge
                            variant={
                              member.isAgent ? 
                                (member.status === 'active' ? 'success' :
                                member.status === 'pending' ? 'warning' :
                                member.status === 'suspended' ? 'danger' : 'secondary')
                              : 'secondary'
                            }
                            size="sm"
                            className="capitalize mr-2"
                          >
                            {member.isAgent ? member.status : 'customer'}
                          </Badge>
                          <span className="text-xs text-gray-500">
                            {member.isAgent ? `Level ${member.level}` : 'Customer'} • Joined {formatDate(member.createdAt)}
                          </span>
                        </div>
                      </div>
                    </div>
                    
                    {member.isAgent ? (
                      <div className="flex items-center space-x-4">
                        <div>
                          <p className="text-xs text-gray-500">Commission Rate</p>
                          <div className="flex items-center">
                            <input
                              type="number"
                              min="0"
                              max="100"
                              value={member.commissionRate}
                              onChange={(e) => handleUpdateCommissionRate(member.userId, parseFloat(e.target.value))}
                              className="w-12 px-2 py-1 border border-gray-300 rounded mr-1 text-sm"
                              onClick={(e) => e.stopPropagation()}
                            />
                            <span className="text-gray-700 text-sm">%</span>
                          </div>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Earnings</p>
                          <p className="font-semibold text-gray-900">{formatCurrency(member.totalEarnings)}</p>
                        </div>
                        <Select
                          value={member.status}
                          onChange={(e) => {
                            e.stopPropagation();
                            handleUpdateStatus(member.userId, e.target.value);
                          }}
                          options={[
                            { value: 'active', label: 'Active' },
                            { value: 'pending', label: 'Pending' },
                            { value: 'suspended', label: 'Suspended' },
                            { value: 'inactive', label: 'Inactive' }
                          ]}
                          className="w-32"
                          onClick={(e) => e.stopPropagation()}
                        />
                      </div>
                    ) : (
                      <div className="flex items-center">
                        <Badge variant="secondary">Customer</Badge>
                      </div>
                    )}
                  </div>
                </div>
                
                {member.expanded && member.isAgent && (
                  <div className="border-t border-gray-200 bg-gray-50 p-6">
                    <h4 className="font-medium text-gray-900 mb-4">Order Statistics</h4>
                    {member.orderStats ? (
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="bg-white p-4 rounded-lg shadow-sm">
                          <h5 className="text-sm font-medium text-gray-700 mb-2">Total Orders</h5>
                          <p className="text-xl font-bold text-gray-900">{member.orderStats.totalOrders}</p>
                          <p className="text-sm text-gray-600">{formatCurrency(member.orderStats.totalAmount)}</p>
                        </div>
                        <div className="bg-white p-4 rounded-lg shadow-sm">
                          <h5 className="text-sm font-medium text-gray-700 mb-2">Processing</h5>
                          <p className="text-xl font-bold text-gray-900">{member.orderStats.processingOrders}</p>
                          <p className="text-sm text-gray-600">{formatCurrency(member.orderStats.processingAmount)}</p>
                        </div>
                        <div className="bg-white p-4 rounded-lg shadow-sm">
                          <h5 className="text-sm font-medium text-gray-700 mb-2">Completed</h5>
                          <p className="text-xl font-bold text-gray-900">{member.orderStats.completedOrders}</p>
                          <p className="text-sm text-gray-600">{formatCurrency(member.orderStats.completedAmount)}</p>
                        </div>
                      </div>
                    ) : (
                      <div className="flex justify-center items-center h-24">
                        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
                      </div>
                    )}
                  </div>
                )}
                
                {member.expanded && !member.isAgent && (
                  <div className="border-t border-gray-200 bg-gray-50 p-6">
                    <h4 className="font-medium text-gray-900 mb-4">Customer Information</h4>
                    <p className="text-gray-600">
                      This customer was referred by you and is part of your team. They can make purchases through your referral link.
                    </p>
                    {member.orderStats ? (
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
                        <div className="bg-white p-4 rounded-lg shadow-sm">
                          <h5 className="text-sm font-medium text-gray-700 mb-2">Total Orders</h5>
                          <p className="text-xl font-bold text-gray-900">{member.orderStats.totalOrders}</p>
                          <p className="text-sm text-gray-600">{formatCurrency(member.orderStats.totalAmount)}</p>
                        </div>
                        <div className="bg-white p-4 rounded-lg shadow-sm">
                          <h5 className="text-sm font-medium text-gray-700 mb-2">Processing</h5>
                          <p className="text-xl font-bold text-gray-900">{member.orderStats.processingOrders}</p>
                          <p className="text-sm text-gray-600">{formatCurrency(member.orderStats.processingAmount)}</p>
                        </div>
                        <div className="bg-white p-4 rounded-lg shadow-sm">
                          <h5 className="text-sm font-medium text-gray-700 mb-2">Completed</h5>
                          <p className="text-xl font-bold text-gray-900">{member.orderStats.completedOrders}</p>
                          <p className="text-sm text-gray-600">{formatCurrency(member.orderStats.completedAmount)}</p>
                        </div>
                      </div>
                    ) : (
                      <div className="flex justify-center items-center h-24">
                        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
                      </div>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          ))
        )}
      </div>
      
      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-md">
            <CardHeader className="flex justify-between items-center">
              <CardTitle>Add Team Member</CardTitle>
              <button 
                onClick={() => setShowAddModal(false)}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="h-5 w-5" />
              </button>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                <Input
                  label="Username"
                  value={newTeamMember.username}
                  onChange={(e) => setNewTeamMember({ ...newTeamMember, username: e.target.value })}
                  placeholder="Enter existing username"
                  required
                  disabled={isAddingTeamMember}
                />
                
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mt-4">
                  <p className="text-sm text-blue-700">
                    Enter the username of an existing user to add them to your team.
                    They will be added as a customer by default.
                  </p>
                </div>
                
                <div className="flex justify-end gap-2 mt-6">
                  <Button
                    variant="outline"
                    onClick={() => setShowAddModal(false)}
                    disabled={isAddingTeamMember}
                    className="w-1/3"
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleAddTeamMember}
                    isLoading={isAddingTeamMember}
                    className="w-2/3"
                  >
                    Add Team Member
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

export default AgentTeamPage;