import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Package, ChevronRight, Search, Share2, DollarSign, ShoppingBag, Clock, TrendingUp, Truck } from 'lucide-react';
import { Card, CardContent } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Badge from '../../components/ui/Badge';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { formatCurrency, formatDate, generateShareableLink } from '../../lib/utils';
import { Order } from '../../types';
import { supabase } from '../../lib/supabase';
import { toast } from 'react-hot-toast';

const statusColors = {
  pending: 'warning',
  processing: 'primary',
  shipped: 'secondary',
  delivered: 'success',
  cancelled: 'danger'
} as const;

interface OrderStats {
  totalOrders: number;
  totalSpent: number;
  pendingOrders: number;
  processingOrders: number;
  processingAmount: number;
  completedOrders: number;
  monthlyStats: {
    month: string;
    total: number;
    count: number;
  }[];
}

function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [orderStats, setOrderStats] = useState<OrderStats>({
    totalOrders: 0,
    totalSpent: 0,
    pendingOrders: 0,
    processingOrders: 0,
    processingAmount: 0,
    completedOrders: 0,
    monthlyStats: []
  });

  useEffect(() => {
    const fetchOrders = async () => {
      try {
        const { data, error } = await supabase
          .from('orders')
          .select(`
            *,
            order_items (
              *,
              product:products (*)
            ),
            shared_orders (
              share_id,
              status
            )
          `)
          .order('created_at', { ascending: false });

        if (error) throw error;

        setOrders(data || []);

        // Calculate processing orders and amount
        const processingOrders = data?.filter(order => order.status === 'processing') || [];
        const processingAmount = processingOrders.reduce((sum, order) => sum + order.total, 0) || 0;
        
        // Calculate order statistics
        const stats: OrderStats = {
          totalOrders: data?.length || 0,
          totalSpent: data?.reduce((sum, order) => sum + order.total, 0) || 0,
          pendingOrders: data?.filter(order => order.status === 'pending').length || 0,
          processingOrders: processingOrders.length,
          processingAmount: processingAmount,
          completedOrders: data?.filter(order => order.status === 'delivered').length || 0,
          monthlyStats: []
        };
        
        // Calculate monthly statistics
        const monthlyData = new Map<string, { total: number; count: number }>();
        data?.forEach(order => {
          const month = new Date(order.created_at).toLocaleString('en-US', { month: 'short', year: 'numeric' });
          const existing = monthlyData.get(month) || { total: 0, count: 0 };
          monthlyData.set(month, {
            total: existing.total + order.total,
            count: existing.count + 1
          });
        });
        
        stats.monthlyStats = Array.from(monthlyData.entries())
          .map(([month, data]) => ({
            month,
            total: data.total,
            count: data.count
          }))
          .sort((a, b) => new Date(b.month) - new Date(a.month))
          .slice(0, 6);
        
        setOrderStats(stats);
      } catch (error) {
        console.error('Error fetching orders:', error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchOrders();
  }, []);

  const filteredOrders = orders.filter(order => {
    const matchesSearch = searchQuery === '' ||
      (order.order_number || '').toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesStatus = statusFilter === 'all' ||
      order.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">Your Orders</h1>
      
      {/* Order Statistics */}
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
              {orderStats.totalOrders}
            </div>
            <p className="text-sm text-gray-600">
              {orderStats.pendingOrders} pending
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
            <h3 className="text-lg font-semibold text-gray-900">Total Spent</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(orderStats.totalSpent)}
            </div>
            <p className="text-sm text-gray-600">
              Lifetime purchases
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
              {orderStats.processingOrders}
            </div>
            <p className="text-sm text-gray-600">
              {formatCurrency(orderStats.processingAmount)}
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
            <h3 className="text-lg font-semibold text-gray-900">Completed Orders</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {orderStats.completedOrders}
            </div>
            <p className="text-sm text-gray-600">
              Successfully delivered
            </p>
          </CardContent>
        </Card>
      </div>
      
      {/* Monthly Statistics */}
      {orderStats.monthlyStats.length > 0 && (
        <Card className="mb-8">
          <CardContent className="p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Monthly Order History</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {orderStats.monthlyStats.map((stat, index) => (
                <div key={index} className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div>
                    <p className="text-sm font-medium text-gray-600">{stat.month}</p>
                    <p className="text-lg font-semibold text-gray-900">{formatCurrency(stat.total)}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-gray-600">{stat.count} orders</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
      
      <div className="mb-6 flex flex-col sm:flex-row gap-4">
        <Input
          placeholder="Search orders..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          leftIcon={<Search className="h-5 w-5" />}
          className="flex-grow"
        />
        
        <Select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          options={[
            { value: 'all', label: 'All Orders' },
            { value: 'pending', label: 'Pending' },
            { value: 'processing', label: 'Processing' },
            { value: 'shipped', label: 'Shipped' },
            { value: 'delivered', label: 'Delivered' },
            { value: 'cancelled', label: 'Cancelled' }
          ]}
          className="w-full sm:w-48"
        />
      </div>
      
      {filteredOrders.length === 0 ? (
        <Card className="p-12 text-center">
          <Package className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h2 className="text-xl font-semibold text-gray-900 mb-2">No orders found</h2>
          <p className="text-gray-600 mb-6">
            {searchQuery || statusFilter !== 'all'
              ? "No orders match your search criteria"
              : "You haven't placed any orders yet"}
          </p>
          <Link
            to="/products"
            className="text-blue-600 hover:text-blue-800 font-medium"
          >
            Start Shopping
          </Link>
        </Card>
      ) : (
        <div className="space-y-4">
          {filteredOrders.map((order) => (
            <Card key={order.id} className="p-6">
              <div className="flex flex-col md:flex-row md:items-center justify-between mb-4">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-1">
                    Order #{order.order_number || 'N/A'}
                  </h3>
                  <p className="text-sm text-gray-500">
                    Placed on {formatDate(order.created_at)}
                  </p>
                </div>
                <div className="mt-4 md:mt-0 flex items-center gap-4">
                  <Badge
                    variant={statusColors[order.status as keyof typeof statusColors]}
                    className="capitalize"
                  >
                    {order.status}
                  </Badge>
                  {order.payment_method === 'friend_payment' && 
                   order.status !== 'cancelled' && 
                   order.payment_status === 'pending' && (
                    <div className="flex items-center gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        className="flex items-center gap-2"
                        onClick={async () => {
                          try {
                            // Create or get share link
                            const { data, error } = await supabase.rpc('share_order', {
                              p_order_id: order.id
                            });
                            
                            if (error) throw error;
                            if (!data?.success) throw new Error(data?.error || 'Failed to create share link');
                            
                            const shareLink = generateShareableLink(data.share_id);
                            await navigator.clipboard.writeText(shareLink);
                            
                            toast.success('Share link copied to clipboard!');
                          } catch (err) {
                            toast.error('Failed to copy link');
                          }
                        }}
                      >
                        <Share2 className="h-4 w-4" />
                        Share Link
                      </Button>
                    </div>
                  )}
                  <Link
                    to={`/orders/${order.id}`}
                    className="text-blue-600 hover:text-blue-800 flex items-center"
                  >
                    View Details
                    <ChevronRight className="h-4 w-4 ml-1" />
                  </Link>
                </div>
              </div>
              
              <div className="border-t border-gray-200 pt-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                  <div>
                    <label className="text-sm font-medium text-gray-700">Items</label>
                    <p className="mt-1">
                      {order.order_items?.reduce((sum, item) => sum + item.quantity, 0) || 0} items
                    </p>
                  </div>
                  <div>
                    <label className="text-sm font-medium text-gray-700">Total</label>
                    <p className="mt-1 font-semibold">
                      {formatCurrency(order.total)}
                    </p>
                  </div>
                  <div>
                    <label className="text-sm font-medium text-gray-700">Payment</label>
                    <p className="mt-1 capitalize">
                      {(order.payment_method || '').replace('_', ' ')}
                    </p>
                  </div>
                  {order.tracking_number && (
                    <div>
                      <label className="text-sm font-medium text-gray-700">Tracking</label>
                      <p className="mt-1">{order.tracking_number}</p>
                    </div>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

export default OrdersPage;