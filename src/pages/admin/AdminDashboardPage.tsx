import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  ShoppingBag, Users, DollarSign, Package, TrendingUp, Settings, Wallet,
  UserCheck, CreditCard, ChevronRight, AlertCircle, Truck
} from 'lucide-react';
import { Card, CardContent } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { formatCurrency } from '../../lib/utils';
import { supabase, testConnection, safeQuery } from '../../lib/supabase';

interface DashboardStats {
  totalOrders: number;
  totalProducts: number;
  totalUsers: number;
  totalRevenue: number;
  processingOrdersCount: number;
  processingOrdersAmount: number;
  pendingWithdrawals: number;
  pendingWithdrawalsCount: number;
  pendingOrders: number;
  lowStockProducts: number;
  activeAgents: number;
  monthlyRevenue: number;
  recentOrders: Array<{
    id: string;
    orderNumber: string;
    status: string;
    total: number;
    itemCount: number;
  }>;
}

const AdminDashboardPage = () => {
  const [stats, setStats] = useState<DashboardStats>({
    totalOrders: 0,
    totalProducts: 0,
    totalUsers: 0,
    totalRevenue: 0,
    processingOrdersCount: 0,
    processingOrdersAmount: 0,
    pendingWithdrawals: 0,
    pendingWithdrawalsCount: 0,
    pendingOrders: 0,
    lowStockProducts: 0,
    activeAgents: 0,
    monthlyRevenue: 0,
    recentOrders: []
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setError(null);
        
        try {
          // Test connection first
          await testConnection();
        } catch (connError) {
          setError('Unable to connect to Supabase. Please check your connection and ensure you have connected to Supabase.');
          setIsLoading(false);
          return;
        }

        // Fetch total orders and revenue
        const { data: orders, error: ordersError } = await safeQuery('orders', supabase
          .from('orders')
          .select('id, total, status, created_at'));

        if (ordersError) {
          console.error('Error fetching orders:', ordersError);
          throw new Error(`Failed to fetch orders: ${ordersError.message}`);
        }

        // Fetch products
        const { data: products, error: productsError } = await safeQuery('products', supabase
          .from('products')
          .select('id, inventory'));
        
        if (productsError) {
          console.error('Error fetching products:', productsError);
          throw new Error(`Failed to fetch products: ${productsError.message}`);
        }

        // Fetch users
        const { data: users, error: usersError } = await safeQuery('user_profiles', supabase
          .from('user_profiles')
          .select('id, role'));
        
        if (usersError) {
          console.error('Error fetching users:', usersError);
          throw new Error(`Failed to fetch users: ${usersError.message}`);
        }

        // Fetch agents
        const { data: agents, error: agentsError } = await safeQuery('agents', supabase
          .from('agents')
          .select('user_id, status'));
        
        if (agentsError) {
          console.error('Error fetching agents:', agentsError);
          throw new Error(`Failed to fetch agents: ${agentsError.message}`);
        }

        // Fetch pending withdrawals
        const { data: pendingWithdrawals, error: withdrawalsError } = await safeQuery('pending_withdrawals', supabase
          .from('wallet_transactions')
          .select('id, amount')
          .eq('type', 'withdrawal')
          .eq('status', 'pending'));
        
        if (withdrawalsError) {
          console.error('Error fetching pending withdrawals:', withdrawalsError);
          throw new Error(`Failed to fetch pending withdrawals: ${withdrawalsError.message}`);
        }

        // Fetch recent orders with items
        const { data: recentOrders, error: recentError } = await safeQuery('recent_orders', supabase
          .from('orders')
          .select(`
            id,
            order_number,
            status,
            total,
            order_items (
              quantity
            )
          `)
          .order('created_at', { ascending: false })
          .limit(5));
        
        if (recentError) {
          console.error('Error fetching recent orders:', recentError);
          throw new Error(`Failed to fetch recent orders: ${recentError.message}`);
        }

        // Calculate monthly revenue
        const now = new Date();
        const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const monthlyOrders = orders?.filter(order => 
          new Date(order.created_at) >= firstDayOfMonth
        ) || [];

        const monthlyRevenue = monthlyOrders.reduce((sum, order) => 
          sum + (order.total || 0), 0
        );
        
        // Calculate processing orders count and amount
        const processingOrders = orders?.filter(order => order.status === 'processing') || [];
        const processingOrdersCount = processingOrders.length;
        const processingOrdersAmount = processingOrders.reduce((sum, order) => 
          sum + (order.total || 0), 0
        );
        
        // Calculate pending withdrawals
        const pendingWithdrawalsAmount = pendingWithdrawals?.reduce((sum, withdrawal) => 
          sum + (withdrawal.amount || 0), 0
        ) || 0;

        // Calculate dashboard stats
        setStats({
          totalOrders: orders?.length || 0,
          totalProducts: products?.length || 0,
          totalUsers: users?.length || 0,
          totalRevenue: orders?.reduce((sum, order) => sum + (order.total || 0), 0) || 0,
          processingOrdersCount,
          processingOrdersAmount,
          pendingWithdrawals: pendingWithdrawalsAmount,
          pendingWithdrawalsCount: pendingWithdrawals?.length || 0,
          pendingOrders: orders?.filter(order => 
            ['pending', 'processing'].includes(order.status)
          ).length || 0,
          lowStockProducts: products?.filter(product => 
            (product.inventory || 0) < 10
          ).length || 0,
          activeAgents: agents?.filter(agent => 
            agent.status === 'active'
          ).length || 0,
          monthlyRevenue,
          recentOrders: recentOrders?.map(order => ({
            id: order.id,
            orderNumber: order.order_number,
            status: order.status,
            total: order.total,
            itemCount: order.order_items?.reduce((sum, item) => 
              sum + (item.quantity || 0), 0
            ) || 0
          })) || []
        });
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
        setError(error.message || 'Failed to fetch dashboard data. Please check your connection and try again.');
      } finally {
        setIsLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-8"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {[...Array(2)].map((_, i) => (
              <div key={i} className="h-64 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 mb-8">
          <div className="flex items-center mb-4">
            <AlertCircle className="h-6 w-6 text-red-500 mr-2" />
            <h2 className="text-lg font-semibold text-red-700">Connection Error</h2>
          </div>
          <p className="text-red-600 mb-4">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="bg-red-100 text-red-700 px-4 py-2 rounded-md hover:bg-red-200 transition-colors"
          >
            Retry Connection
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <Link 
          to="/admin/settings"
          className="flex items-center text-gray-600 hover:text-gray-900"
        >
          <Settings className="h-5 w-5 mr-2" />
          Settings
        </Link>
      </div>
      
      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card className="bg-gradient-to-br from-blue-50 to-blue-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <ShoppingBag className="h-6 w-6 text-blue-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Total Orders</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {stats.totalOrders}
            </div>
            <p className="text-sm text-gray-600">
              {stats.pendingOrders} pending
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
            <h3 className="text-lg font-semibold text-gray-900">Total Revenue</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(stats.totalRevenue)}
            </div>
            <p className="text-sm text-gray-600">
              {formatCurrency(stats.monthlyRevenue)} this month
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
              {stats.processingOrdersCount}
            </div>
            <p className="text-sm text-gray-600">
              {formatCurrency(stats.processingOrdersAmount)}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-indigo-50 to-indigo-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-indigo-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <Wallet className="h-6 w-6 text-indigo-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Pending Withdrawals</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {stats.pendingWithdrawalsCount}
            </div>
            <p className="text-sm text-gray-600">
              {formatCurrency(stats.pendingWithdrawals)}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-purple-50 to-purple-100 hover:shadow-md transition-shadow">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-purple-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <Users className="h-6 w-6 text-purple-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Total Users</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {stats.totalUsers}
            </div>
            <p className="text-sm text-gray-600">
              {stats.activeAgents} active agents
            </p>
          </CardContent>
        </Card>
      </div>
      
      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <Link to="/admin/products">
          <Card className="hover:shadow-md transition-shadow">
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mr-4">
                    <Package className="h-5 w-5 text-blue-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900">Manage Products</h3>
                    <p className="text-sm text-gray-500">Add, edit, and manage inventory</p>
                  </div>
                </div>
                <ChevronRight className="h-5 w-5 text-gray-400" />
              </div>
            </CardContent>
          </Card>
        </Link>

        <Link to="/admin/users">
          <Card className="hover:shadow-md transition-shadow">
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center mr-4">
                    <UserCheck className="h-5 w-5 text-purple-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900">Manage Users</h3>
                    <p className="text-sm text-gray-500">View and manage user accounts</p>
                  </div>
                </div>
                <ChevronRight className="h-5 w-5 text-gray-400" />
              </div>
            </CardContent>
          </Card>
        </Link>

        <Link to="/admin/agents">
          <Card className="hover:shadow-md transition-shadow">
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center mr-4">
                    <TrendingUp className="h-5 w-5 text-green-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900">Agent Network</h3>
                    <p className="text-sm text-gray-500">Manage agents and commissions</p>
                  </div>
                </div>
                <ChevronRight className="h-5 w-5 text-gray-400" />
              </div>
            </CardContent>
          </Card>
        </Link>
      </div>
      
      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardContent className="p-6">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-semibold text-gray-900">Recent Orders</h3>
              <Link 
                to="/admin/orders" 
                className="text-sm text-blue-600 hover:text-blue-800"
              >
                View All
              </Link>
            </div>
            <div className="space-y-4">
              {stats.recentOrders.map(order => (
                <div key={order.id} className="flex items-center justify-between py-2">
                  <div className="flex items-center">
                    <div className="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center mr-3">
                      <Package className="h-4 w-4 text-gray-600" />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">Order #{order.orderNumber}</p>
                      <p className="text-sm text-gray-500">
                        {order.itemCount} items • {order.status}
                      </p>
                    </div>
                  </div>
                  <span className="font-medium">{formatCurrency(order.total)}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-semibold text-gray-900">Payment Settings</h3>
              <Link 
                to="/admin/settings/payment" 
                className="text-sm text-blue-600 hover:text-blue-800"
              >
                Configure
              </Link>
            </div>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center">
                  <CreditCard className="h-5 w-5 text-gray-600 mr-3" />
                  <div>
                    <p className="font-medium text-gray-900">Payment Gateway</p>
                    <p className="text-sm text-gray-500">Stripe • Connected</p>
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Link to="/admin/agents">
          <Card className="hover:shadow-md transition-shadow">
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center mr-4">
                    <Wallet className="h-5 w-5 text-indigo-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900">Agent Wallets</h3>
                    <p className="text-sm text-gray-500">Manage agent earnings and withdrawals</p>
                  </div>
                </div>
                <ChevronRight className="h-5 w-5 text-gray-400" />
              </div>
            </CardContent>
          </Card>
        </Link>
      </div>
    </div>
  );
};

export default AdminDashboardPage;