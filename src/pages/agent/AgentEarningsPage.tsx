import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  DollarSign, ArrowUpRight, ArrowDownRight, 
  Calendar, Filter, ChevronDown, ChevronUp, 
  Clock, CheckCircle, XCircle, AlertCircle,
  CreditCard, ExternalLink
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatCurrency, formatDate } from '../../lib/utils';
import { toast } from 'react-hot-toast';
import { useAuthStore } from '../../store/auth-store';

interface WalletSummary {
  current_balance: number;
  total_earnings: number;
  pending_withdrawals: number;
  completed_withdrawals: number;
  last_transaction: {
    id: string;
    amount: number;
    type: string;
    status: string;
    created_at: string;
  } | null;
}

interface WalletTransaction {
  transaction_id: string;
  amount: number;
  type: 'deposit' | 'withdrawal' | 'commission' | 'adjustment';
  status: 'pending' | 'completed' | 'rejected' | 'cancelled';
  notes: string | null;
  created_at: string;
  completed_at: string | null;
  reference_id: string | null;
  admin_username: string | null;
}

const AgentEarningsPage: React.FC = () => {
  const { user } = useAuthStore();
  const [transactions, setTransactions] = useState<WalletTransaction[]>([]);
  const [walletSummary, setWalletSummary] = useState<WalletSummary | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [filterType, setFilterType] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [isFiltersOpen, setIsFiltersOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    if (user?.id) {
      fetchWalletSummary();
      fetchTransactions();
    }
  }, [user?.id, currentPage, filterType, filterStatus]);

  const fetchWalletSummary = async () => {
    try {
      const { data, error } = await supabase.rpc('get_agent_wallet_summary', {
        p_agent_id: user?.id
      });

      if (error) throw error;
      
      if (data && data.success) {
        setWalletSummary(data);
      }
    } catch (error) {
      console.error('Error fetching wallet summary:', error);
      toast.error('Failed to load wallet summary');
    }
  };

  const fetchTransactions = async () => {
    setIsLoading(true);
    try {
      // Calculate offset based on current page
      const offset = (currentPage - 1) * itemsPerPage;
      
      // Fetch transactions
      const { data, error } = await supabase.rpc('get_agent_wallet_transactions', {
        p_agent_id: user?.id,
        p_limit: itemsPerPage,
        p_offset: offset
      });

      if (error) throw error;
      
      // Apply filters
      let filteredData = [...(data || [])];
      
      if (filterType !== 'all') {
        filteredData = filteredData.filter(t => t.type === filterType);
      }
      
      if (filterStatus !== 'all') {
        filteredData = filteredData.filter(t => t.status === filterStatus);
      }
      
      setTransactions(filteredData);
      
      // Get total count for pagination
      const { count, error: countError } = await supabase
        .from('wallet_transactions')
        .select('id', { count: 'exact', head: true })
        .eq('agent_id', user?.id);
      
      if (countError) throw countError;
      
      setTotalPages(Math.ceil((count || 0) / itemsPerPage));
    } catch (error) {
      console.error('Error fetching transactions:', error);
      toast.error('Failed to load transactions');
    } finally {
      setIsLoading(false);
    }
  };

  const getTransactionStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
        return <Badge variant="success">Completed</Badge>;
      case 'pending':
        return <Badge variant="warning">Pending</Badge>;
      case 'rejected':
        return <Badge variant="danger">Rejected</Badge>;
      case 'cancelled':
        return <Badge variant="secondary">Cancelled</Badge>;
      default:
        return <Badge>{status}</Badge>;
    }
  };

  const getTransactionTypeIcon = (type: string) => {
    switch (type) {
      case 'deposit':
        return <ArrowUpRight className="h-4 w-4 text-green-500" />;
      case 'withdrawal':
        return <ArrowDownRight className="h-4 w-4 text-red-500" />;
      case 'commission':
        return <DollarSign className="h-4 w-4 text-blue-500" />;
      case 'adjustment':
        return <ExternalLink className="h-4 w-4 text-purple-500" />;
      default:
        return <DollarSign className="h-4 w-4" />;
    }
  };

  const getTransactionTypeLabel = (type: string) => {
    switch (type) {
      case 'deposit':
        return 'Deposit';
      case 'withdrawal':
        return 'Withdrawal';
      case 'commission':
        return 'Commission';
      case 'adjustment':
        return 'Adjustment';
      default:
        return type;
    }
  };

  if (isLoading && !walletSummary) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="h-64 bg-gray-200 rounded mb-8"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">My Earnings</h1>
      </div>

      {/* Wallet Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <Card className="bg-gradient-to-br from-blue-50 to-blue-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <DollarSign className="h-6 w-6 text-blue-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Available Balance</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(walletSummary?.current_balance || 0)}
            </div>
            <p className="text-sm text-gray-600">
              Ready to withdraw
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
            <h3 className="text-lg font-semibold text-gray-900">Total Earnings</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(walletSummary?.total_earnings || 0)}
            </div>
            <p className="text-sm text-gray-600">
              Lifetime earnings
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Transactions List */}
      <Card className="mb-8">
        <CardHeader className="flex flex-col sm:flex-row justify-between items-start sm:items-center">
          <CardTitle>Transaction History</CardTitle>
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => setIsFiltersOpen(!isFiltersOpen)}
            rightIcon={isFiltersOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
          >
            <Filter className="h-4 w-4 mr-2" />
            Filters
          </Button>
        </CardHeader>
        
        {isFiltersOpen && (
          <div className="px-6 pb-4 border-b border-gray-200">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Select
                label="Transaction Type"
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
                options={[
                  { value: 'all', label: 'All Types' },
                  { value: 'deposit', label: 'Deposits' },
                  { value: 'withdrawal', label: 'Withdrawals' },
                  { value: 'commission', label: 'Commissions' },
                  { value: 'adjustment', label: 'Adjustments' }
                ]}
              />
              
              <Select
                label="Status"
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                options={[
                  { value: 'all', label: 'All Statuses' },
                  { value: 'completed', label: 'Completed' },
                  { value: 'pending', label: 'Pending' },
                  { value: 'rejected', label: 'Rejected' },
                  { value: 'cancelled', label: 'Cancelled' }
                ]}
              />
            </div>
          </div>
        )}
        
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {transactions.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-12 text-center text-gray-500">
                      <div className="flex flex-col items-center">
                        <DollarSign className="h-12 w-12 text-gray-300 mb-4" />
                        <p className="text-lg font-medium text-gray-900 mb-1">No transactions found</p>
                        <p className="text-gray-500">
                          {filterType !== 'all' || filterStatus !== 'all' 
                            ? 'Try adjusting your filters'
                            : 'Your transaction history will appear here'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  transactions.map((transaction) => (
                    <tr key={transaction.transaction_id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">
                          {formatDate(transaction.created_at)}
                        </div>
                        {transaction.completed_at && (
                          <div className="text-xs text-gray-500">
                            Completed: {formatDate(transaction.completed_at)}
                          </div>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          {getTransactionTypeIcon(transaction.type)}
                          <span className="ml-2 text-sm text-gray-900">
                            {getTransactionTypeLabel(transaction.type)}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className={`text-sm font-medium ${
                          transaction.type === 'withdrawal' ? 'text-red-600' : 'text-green-600'
                        }`}>
                          {transaction.type === 'withdrawal' ? '-' : '+'}{formatCurrency(transaction.amount)}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {getTransactionStatusBadge(transaction.status)}
                      </td>
                      <td className="px-6 py-4">
                        <div className="text-sm text-gray-900 max-w-xs truncate">
                          {transaction.notes || 
                            (transaction.reference_id ? `Reference: ${transaction.reference_id}` : '-')}
                        </div>
                        {transaction.admin_username && (
                          <div className="text-xs text-gray-500">
                            Processed by: {transaction.admin_username}
                          </div>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          
          {/* Pagination */}
          {totalPages > 1 && (
            <div className="px-6 py-4 flex items-center justify-between border-t border-gray-200">
              <div className="text-sm text-gray-500">
                Page {currentPage} of {totalPages}
              </div>
              <div className="flex space-x-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                  disabled={currentPage === 1}
                >
                  Previous
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                  disabled={currentPage === totalPages}
                >
                  Next
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

    </div>
  );
};

export default AgentEarningsPage;