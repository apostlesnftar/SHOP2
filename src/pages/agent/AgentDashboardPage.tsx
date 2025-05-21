import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  DollarSign, Users, Package, TrendingUp, CreditCard, BarChart3, 
  Calendar, ChevronRight, ArrowUpRight, ArrowDownRight, ShoppingBag, Clock
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import { formatCurrency, formatDate } from '../../lib/utils';
import { useAuthStore } from '../../store/auth-store';
import { supabase, getCurrentUser } from '../../lib/supabase';
import { toast } from 'react-hot-toast';

// Mock data for charts
const mockRevenueData = [
  { month: 'Jan', revenue: 1250 },
  { month: 'Feb', revenue: 1800 },
  { month: 'Mar', revenue: 1350 },
  { month: 'Apr', revenue: 2100 },
  { month: 'May', revenue: 1950 },
  { month: 'Jun', revenue: 2400 },
];

const mockReferralsData = [
  { month: 'Jan', referrals: 3 },
  { month: 'Feb', referrals: 5 },
  { month: 'Mar', referrals: 2 },
  { month: 'Apr', referrals: 4 },
  { month: 'May', referrals: 6 },
  { month: 'Jun', referrals: 4 },
];

const AgentDashboardPage: React.FC = () => {
  const { user } = useAuthStore();
  const [processingStats, setProcessingStats] = useState({ count: 0, total: 0 });
  const [agentData, setAgentData] = useState<any>(null);
  const [teamStats, setTeamStats] = useState({
    teamSize: 0,
    totalEarnings: 0,
    totalOrders: 0, 
    totalAmount: 0,
    processingOrders: 0,
    processingAmount: 0,
    completedOrders: 0,
    completedAmount: 0
  });
  const [teamMembers, setTeamMembers] = useState<any[]>([]);
  const [walletTransactions, setWalletTransactions] = useState<any[]>([]);
  const [walletSummary, setWalletSummary] = useState<any>(null);
  const [timeframe, setTimeframe] = useState<'week' | 'month' | 'year'>('month');
  const [isLoading, setIsLoading] = useState(true);
  const [isCreatingAgent, setIsCreatingAgent] = useState(false);
  
  useEffect(() => {
    checkAgentStatus();
    fetchTeamStats();
    fetchTeamMembers();
    fetchWalletTransactions();
    fetchWalletSummary();
    
    const fetchProcessingStats = async () => {
      if (!user?.id) return;
      
      try {
        const { data, error } = await supabase.rpc('get_agent_processing_orders_stats', {
          p_agent_id: user.id
        });
        
        if (error) throw error;
        
        if (data && data.success) {
          setProcessingStats({
            count: data.count || 0,
            total: data.total || 0
          });
        }
      } catch (error) {
        console.error('Error fetching processing stats:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchProcessingStats();
  }, [user?.id]);
  
  const fetchWalletSummary = async () => {
    if (!user?.id) return;
    
    try {
      const { data, error } = await supabase.rpc('get_agent_wallet_summary', {
        p_agent_id: user.id
      });
      
      if (error) throw error;
      
      if (data && data.success) {
        setWalletSummary(data);
      }
    } catch (error) {
      console.error('Error fetching wallet summary:', error);
    }
  };
  
  const fetchTeamMembers = async () => {
    if (!user?.id) return;
    
    try {
      const { data, error } = await supabase.rpc('get_agent_dashboard_team', {
        p_agent_id: user.id,
        p_limit: 3
      });
      
      if (error) throw error;
      
      setTeamMembers(data || []);
    } catch (error) {
      console.error('Error fetching team members:', error);
    }
  };
  
  const fetchTeamStats = async () => {
    if (!user?.id) return;
    
    try {
      const { data, error } = await supabase.rpc('get_agent_team_stats', {
        p_agent_id: user.id
      });
      
      if (error) throw error;
      
      if (data && data.success) {
        setTeamStats({
          teamSize: data.team_size || 0,
          totalEarnings: data.total_earnings || 0,
          totalOrders: data.total_orders || 0,
          totalAmount: data.total_amount || 0,
          processingOrders: data.processing_orders || 0,
          processingAmount: data.processing_amount || 0,
          completedOrders: data.completed_orders || 0,
          completedAmount: data.completed_amount || 0
        });
      }
    } catch (error) {
      console.error('Error fetching team stats:', error);
    }
  };
  
  const fetchWalletTransactions = async () => {
    if (!user?.id) return;
    
    try {
      const { data, error } = await supabase.rpc('get_agent_wallet_transactions', {
        p_agent_id: user.id,
        p_limit: 5,
        p_offset: 0
      });
      
      if (error) throw error;
      
      setWalletTransactions(data || []);
    } catch (error) {
      console.error('Error fetching wallet transactions:', error);
    }
  };
  
  const checkAgentStatus = async () => {
    if (!user?.id) return;
    
    try {
      const { data, error } = await supabase.rpc('check_agent_status', {
        p_user_id: user.id
      });
      
      if (error) throw error;
      
      setAgentData(data);
      setIsLoading(false);
    } catch (error) {
      console.error('Error checking agent status:', error);
      setAgentData(null);
      setIsLoading(false);
    } finally {
      setIsLoading(false);
    }
  };
  
  const handleBecomeAgent = async () => {
    if (!user?.id) return;
    
    setIsCreatingAgent(true);
    try {
      const { data, error } = await supabase.rpc('create_agent_if_not_exists', {
        p_user_id: user.id
      });
      
      if (error) throw error;
      
      if (data && data.success) {
        toast.success('Agent account created successfully!');
        // Refresh user data to update role
        await useAuthStore.getState().refreshUser();
        // Check agent status again
        await checkAgentStatus();
      } else {
        throw new Error('Failed to create agent account');
      }
    } catch (error) {
      console.error('Error creating agent account:', error);
      toast.error('Failed to create agent account');
    } finally {
      setIsCreatingAgent(false);
    }
  };
  
  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-12 text-center">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/2 mx-auto mb-4"></div>
          <div className="h-4 bg-gray-200 rounded w-1/3 mx-auto mb-8"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }
  
  // Check if user is not an agent or agent record doesn't exist
  if (!agentData?.success) {
    return (
      <div className="container mx-auto px-4 py-12 text-center">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">Agent Account Not Found</h1>
        <p className="text-gray-600 mb-6">
          {agentData?.role === 'agent' 
            ? "Your agent account needs to be set up." 
            : "You don't have an agent account yet."}
        </p>
        <Button 
          size="lg" 
          onClick={handleBecomeAgent}
          isLoading={isCreatingAgent}
        >
          Become an Agent
        </Button>
      </div>
    );
  }
  
  // Calculate some statistics based on real data
  const totalCommissions = walletSummary?.total_earnings || agentData?.total_earnings || 0;
  const pendingCommissions = walletTransactions
    .filter(t => t.type === 'commission' && t.status === 'pending')
    .reduce((sum, transaction) => sum + transaction.amount, 0);
  
  // Get the total referrals (team members)
  const totalReferrals = mockReferralsData.reduce((sum, data) => sum + data.referrals, 0);
  
  // Calculate percentage changes (mock data)
  const earningsChange = 18.2; // percentage
  const referralsChange = 12.5; // percentage
  const salesChange = -5.3; // percentage
  
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-1">Agent Dashboard</h1>
          <p className="text-gray-600">
            Welcome back, {user?.username || 'Agent'}! Here's your agent performance overview.
          </p>
        </div>
        
        <div className="mt-4 md:mt-0 flex space-x-2">
          <Button variant="outline" size="sm" onClick={() => setTimeframe('week')} className={timeframe === 'week' ? 'bg-gray-100' : ''}>
            Week
          </Button>
          <Button variant="outline" size="sm" onClick={() => setTimeframe('month')} className={timeframe === 'month' ? 'bg-gray-100' : ''}>
            Month
          </Button>
          <Button variant="outline" size="sm" onClick={() => setTimeframe('year')} className={timeframe === 'year' ? 'bg-gray-100' : ''}>
            Year
          </Button>
        </div>
      </div>
      
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600">
                <DollarSign className="h-6 w-6" />
              </div>
              <span className={`inline-flex items-center ${earningsChange >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {earningsChange >= 0 ? <ArrowUpRight className="h-4 w-4 mr-1" /> : <ArrowDownRight className="h-4 w-4 mr-1" />}
                {Math.abs(earningsChange)}%
              </span>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Total Earnings</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(walletSummary?.total_earnings || agentData?.total_earnings || 0)}
            </div>
            <p className="text-sm text-gray-600">
              Lifetime earnings from commissions
            </p>
          </CardContent>
        </Card>
        
        <Card className="bg-gradient-to-br from-amber-50 to-amber-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center text-amber-600">
                <ShoppingBag className="h-6 w-6" />
              </div>
              <span className={`inline-flex items-center ${salesChange >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {salesChange >= 0 ? <ArrowUpRight className="h-4 w-4 mr-1" /> : <ArrowDownRight className="h-4 w-4 mr-1" />}
                {Math.abs(salesChange)}%
              </span>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Team Sales</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {teamStats.processingOrders + teamStats.completedOrders}
            </div>
            <p className="text-sm text-gray-600">
              {formatCurrency(teamStats.processingAmount + teamStats.completedAmount)}
            </p>
          </CardContent>
        </Card>
        
        <Card className="bg-gradient-to-br from-emerald-50 to-emerald-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center text-emerald-600">
                <CreditCard className="h-6 w-6" />
              </div>
              <span className="text-blue-600">Withdraw</span>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Available Balance</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(walletSummary?.current_balance || agentData?.current_balance || 0)}
            </div>
            <p className="text-sm text-gray-600">
              Ready to withdraw to your bank account
            </p>
          </CardContent>
        </Card>
        
        <Card className="bg-gradient-to-br from-purple-50 to-purple-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center text-purple-600">
                <Users className="h-6 w-6" />
              </div>
              <span className={`inline-flex items-center ${referralsChange >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {referralsChange >= 0 ? <ArrowUpRight className="h-4 w-4 mr-1" /> : <ArrowDownRight className="h-4 w-4 mr-1" />}
                {Math.abs(referralsChange)}%
              </span>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Team Members</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {teamStats.teamSize}
            </div>
            <p className="text-sm text-gray-600">
              Agents in your downline
            </p>
          </CardContent>
        </Card>
      </div>
      
      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle>Earnings Overview</CardTitle>
              <Link to="/agent-earnings" className="text-sm text-blue-600 hover:text-blue-800 flex items-center">
                View Details <ChevronRight className="h-4 w-4 ml-1" />
              </Link>
            </div>
          </CardHeader>
          <CardContent>
            <div className="h-80 flex items-end justify-between">
              {mockRevenueData.map((data, index) => (
                <div key={index} className="flex flex-col items-center">
                  <div className="w-12 bg-blue-600 rounded-t-md" style={{ height: `${data.revenue / 30}px` }}></div>
                  <span className="mt-2 text-xs text-gray-600">{data.month}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle>My Earnings</CardTitle>
              <Link to="/agent-earnings" className="text-sm text-blue-600 hover:text-blue-800 flex items-center">
                View All <ChevronRight className="h-4 w-4 ml-1" />
              </Link>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {walletTransactions.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[600px] text-sm">
                    <thead>
                      <tr className="text-left border-b border-gray-200">
                        <th className="pb-3 font-medium text-gray-900">Type</th>
                        <th className="pb-3 font-medium text-gray-900">Date</th>
                        <th className="pb-3 font-medium text-gray-900">Amount</th>
                        <th className="pb-3 font-medium text-gray-900">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {walletTransactions.map((transaction) => (
                        <tr key={transaction.transaction_id} className="border-b border-gray-200">
                          <td className="py-4 text-gray-900">
                            <div className="flex items-center">
                              {transaction.type === 'commission' && <DollarSign className="h-4 w-4 text-blue-500 mr-1" />}
                              {transaction.type === 'withdrawal' && <ArrowDownRight className="h-4 w-4 text-red-500 mr-1" />}
                              {transaction.type === 'deposit' && <ArrowUpRight className="h-4 w-4 text-green-500 mr-1" />}
                              {transaction.type === 'adjustment' && <TrendingUp className="h-4 w-4 text-purple-500 mr-1" />}
                              {transaction.type.charAt(0).toUpperCase() + transaction.type.slice(1)}
                            </div>
                          </td>
                          <td className="py-4 text-gray-600">
                            {formatDate(transaction.created_at)}
                          </td>
                          <td className="py-4 font-medium text-gray-900">
                            {formatCurrency(transaction.amount)}
                          </td>
                          <td className="py-4">
                            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                              transaction.status === 'completed' ? 'bg-green-100 text-green-800' :
                              transaction.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                              'bg-red-100 text-red-800'
                            }`}>
                              {transaction.status.charAt(0).toUpperCase() + transaction.status.slice(1)}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div className="text-center py-8">
                  <p className="text-gray-500 mb-4">No transaction records found</p>
                  <Link to="/agent-team">
                    <Button variant="outline" size="sm">Grow Your Team</Button>
                  </Link>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
      
      {/* Team and Referral Links */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <Card>
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <CardTitle>Your Team</CardTitle>
                <Link to="/agent-team" className="text-sm text-blue-600 hover:text-blue-800 flex items-center">
                  Manage Team <ChevronRight className="h-4 w-4 ml-1" />
                </Link>
              </div>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full min-w-[500px] text-sm">
                  <thead>
                    <tr className="text-left border-b border-gray-200">
                      <th className="pb-3 font-medium text-gray-900">Agent</th>
                      <th className="pb-3 font-medium text-gray-900">Status</th>
                      <th className="pb-3 font-medium text-gray-900">Joined</th>
                      <th className="pb-3 font-medium text-gray-900">Sales</th>
                    </tr>
                  </thead>
                  <tbody>
                    {teamMembers.length > 0 ? (
                      teamMembers.map((member) => (
                        <tr key={member.user_id} className="border-b border-gray-200">
                          <td className="py-4">
                            <div className="flex items-center">
                              <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-2">
                                <Users className="h-4 w-4" />
                              </div>
                              <div>
                                <p className="font-medium text-gray-900">{member.username}</p>
                                <p className="text-xs text-gray-500">{member.full_name || ''}</p>
                              </div>
                            </div>
                          </td>
                          <td className="py-4">
                            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                              member.status === 'active' ? 'bg-green-100 text-green-800' :
                              member.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                              'bg-red-100 text-red-800'
                            }`}>
                              {member.status}
                            </span>
                          </td>
                          <td className="py-4 text-gray-600">
                            {member.created_at ? formatDate(member.created_at) : 'N/A'}
                          </td>
                          <td className="py-4 font-medium text-gray-900">
                            {formatCurrency(member.total_earnings || 0)}
                          </td>
                        </tr>
                      ))
                    ) : teamStats.teamSize > 0 ? (
                      <tr className="border-b border-gray-200">
                        <td colSpan={4} className="py-4 text-center">
                          <Link to="/agent-team" className="text-blue-600 hover:text-blue-800">
                            View your {teamStats.teamSize} team members
                          </Link>
                        </td>
                      </tr>
                    ) : (
                      <tr className="border-b border-gray-200">
                        <td colSpan={4} className="py-4 text-center text-gray-500">
                          No team members yet
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </div>
        
        <div>
          <Card>
            <CardHeader>
              <CardTitle>Referral Links</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Your Affiliate Link
                </label>
                <div className="flex">
                  <input
                    type="text"
                    readOnly
                    value={`${window.location.origin}/register?ref=${user?.id || ''}`}
                    className="flex-grow rounded-l-md border border-gray-300 px-3 py-2 text-sm bg-gray-50"
                  />
                  <button className="bg-gray-100 border border-gray-300 border-l-0 rounded-r-md px-3 text-gray-600 hover:bg-gray-200">
                    Copy
                  </button>
                </div>
              </div>
              
              <div className="space-y-2">
                <p className="text-sm text-gray-600">Share with:</p>
                <div className="flex space-x-2">
                  <Button size="sm" variant="outline" className="flex-grow">
                    <svg className="h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path fillRule="evenodd" d="M22 12c0-5.523-4.477-10-10-10S2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v6.988C18.343 21.128 22 16.991 22 12z" clipRule="evenodd" />
                    </svg>
                    Facebook
                  </Button>
                  <Button size="sm" variant="outline" className="flex-grow">
                    <svg className="h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M8.29 20.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0022 5.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.072 4.072 0 012.8 9.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 012 18.407a11.616 11.616 0 006.29 1.84" />
                    </svg>
                    Twitter
                  </Button>
                </div>
                <Button size="sm" variant="outline" className="w-full">
                  <svg className="h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path fillRule="evenodd" d="M7.5 6a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0zM3.751 20.105a8.25 8.25 0 0116.498 0 .75.75 0 01-.437.695A18.683 18.683 0 0112 22.5c-2.786 0-5.433-.608-7.812-1.7a.75.75 0 01-.437-.695z" clipRule="evenodd" />
                  </svg>
                  Invite Friends
                </Button>
              </div>
              
              <div className="bg-blue-50 p-3 rounded-md border border-blue-200">
                <h4 className="font-medium text-blue-800 mb-1">Earn More</h4>
                <p className="text-sm text-blue-700 mb-2">
                  You earn {agentData?.commission_rate || 0}% commission on sales through your referral link!
                </p>
                <Link to="/agent-help" className="text-sm font-medium text-blue-600 hover:text-blue-800 flex items-center">
                  Learn more <ChevronRight className="h-4 w-4 ml-1" />
                </Link>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default AgentDashboardPage;