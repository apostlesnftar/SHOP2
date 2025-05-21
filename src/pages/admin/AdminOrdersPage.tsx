import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Package, Search, ChevronRight, DollarSign, ShoppingBag, Clock, TrendingUp } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatCurrency, formatDate } from '../../lib/utils';
import { toast } from 'react-hot-toast';

interface OrderItem {
  id: string;
  product_id: string;
  quantity: number;
  price: number;
  product: {
    name: string;
    images: string[];
  };
}

interface UserProfile {
  username: string;
  full_name: string | null;
}

interface Order {
  id: string;
  order_number: string;
  user_id: string;
  status: string;
  payment_method: string;
  payment_status: string;
  subtotal: number;
  tax: number;
  shipping: number;
  total: number;
  tracking_number: string | null;
  created_at: string;
  updated_at: string;
  order_items: OrderItem[];
  profiles?: UserProfile;
}

const statusColors = {
  pending: 'warning',
  processing: 'primary',
  shipped: 'secondary',
  delivered: 'success',
  cancelled: 'danger'
} as const;

const AdminOrdersPage = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [orderStats, setOrderStats] = useState({
    totalOrders: 0,
    totalRevenue: 0,
    pendingOrders: 0,
    processingOrders: 0,
    completedOrders: 0,
    cancelledOrders: 0
  });

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    try {
      const { data, error } = await supabase
        .from('order_details')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      setOrders(data || []);
      
      // Calculate order statistics
      const stats = {
        totalOrders: data?.length || 0,
        totalRevenue: data?.reduce((sum, order) => sum + order.total, 0) || 0,
        pendingOrders: data?.filter(order => order.status === 'pending').length || 0,
        processingOrders: data?.filter(order => order.status === 'processing').length || 0,
        completedOrders: data?.filter(order => order.status === 'delivered').length || 0,
        cancelledOrders: data?.filter(order => order.status === 'cancelled').length || 0
      };
      
      setOrderStats(stats);
    } catch (error) {
      console.error('Error fetching orders:', error);
      toast.error('Failed to load orders');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpdateStatus = async (orderId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('orders')
        .update({ status: newStatus })
        .eq('id', orderId); // Fixed: Remove explicit table reference

      if (error) throw error;

      toast.success('Order status updated');
      fetchOrders();
    } catch (error) {
      console.error('Error updating order status:', error);
      toast.error('Failed to update order status');
    }
  };

  const handleUpdatePaymentStatus = async (orderId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('orders')
        .update({ payment_status: newStatus })
        .eq('id', orderId); // Fixed: Remove explicit table reference

      if (error) throw error;

      toast.success('Payment status updated');
      fetchOrders();
    } catch (error) {
      console.error('Error updating payment status:', error);
      toast.error('Failed to update payment status');
    }
  };

  const handleUpdateTrackingNumber = async (orderId: string, trackingNumber: string) => {
    try {
      const { error } = await supabase
        .from('orders')
        .update({ tracking_number: trackingNumber })
        .eq('id', orderId); // Fixed: Remove explicit table reference

      if (error) throw error;

      toast.success('Tracking number updated');
      fetchOrders();
    } catch (error) {
      console.error('Error updating tracking number:', error);
      toast.error('Failed to update tracking number');
    }
  };

  const filteredOrders = orders.filter(order => {
    const matchesSearch = 
      order.order_number.toLowerCase().includes(searchQuery.toLowerCase()) || 
      (order.username || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (order.full_name || '').toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesStatus = statusFilter === 'all' || order.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
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
        <h1 className="text-3xl font-bold text-gray-900">Manage Orders</h1>
      </div>
      
      {/* Order Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card className="bg-gradient-to-br from-blue-50 to-blue-100">
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

        <Card className="bg-gradient-to-br from-green-50 to-green-100">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-green-500 bg-opacity-20 rounded-full flex items-center justify-center">
                <DollarSign className="h-6 w-6 text-green-600" />
              </div>
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Total Revenue</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {formatCurrency(orderStats.totalRevenue)}
            </div>
            <p className="text-sm text-gray-600">
              {orderStats.completedOrders} completed orders
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
            <h3 className="text-lg font-semibold text-gray-900">Processing</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {orderStats.processingOrders}
            </div>
            <p className="text-sm text-gray-600">
              Orders in progress
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
            <h3 className="text-lg font-semibold text-gray-900">Completed</h3>
            <div className="text-3xl font-bold text-gray-900 mb-1">
              {orderStats.completedOrders}
            </div>
            <p className="text-sm text-gray-600">
              Successfully delivered
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
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
              className="w-full md:w-48"
            />
          </div>
        </CardContent>
      </Card>

      <div className="space-y-4">
        {filteredOrders.length === 0 ? (
          <Card className="p-12 text-center">
            <Package className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 mb-2">No orders found</h2>
            <p className="text-gray-600">
              {searchQuery || statusFilter !== 'all'
                ? "No orders match your search criteria"
                : "There are no orders yet"}
            </p>
          </Card>
        ) : (
          filteredOrders.map((order) => (
            <Card key={order.id}>
              <CardContent className="p-6">
                <div className="flex flex-col md:flex-row md:items-center justify-between mb-4">
                  <div>
                    <div className="flex items-center gap-3">
                      <h3 className="text-lg font-semibold text-gray-900">
                        Order #{order.order_number}
                        {order.username && (
                          <span className="ml-2 text-sm text-gray-600">
                            by {order.full_name || order.username}
                          </span>
                        )}
                      </h3>
                      <Badge
                        variant={statusColors[order.status as keyof typeof statusColors]}
                        className="capitalize"
                      >
                        {order.status}
                      </Badge>
                      <Badge
                        variant={order.payment_status === 'completed' ? 'success' : 'warning'}
                        className="capitalize"
                      >
                        {order.payment_status}
                      </Badge>
                    </div>
                    <p className="text-sm text-gray-500 mt-1">
                      Placed by {order.username || order.full_name || 'Unknown User'} on {formatDate(order.created_at)}
                    </p>
                  </div>
                  <div className="mt-4 md:mt-0">
                    <Link
                      to={`/admin/orders/${order.id}`}
                      className="text-blue-600 hover:text-blue-800 flex items-center"
                    >
                      View Details
                      <ChevronRight className="h-4 w-4 ml-1" />
                    </Link>
                  </div>
                </div>

                <div className="border-t border-gray-200 pt-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Items</label>
                      <div className="mt-1 space-y-1">
                        {order.order_items.map((item) => (
                          <div key={item.id} className="flex items-center">
                            <img
                              src={item.product.images[0]}
                              alt={item.product.name}
                              className="w-8 h-8 object-cover rounded"
                            />
                            <span className="ml-2 text-sm text-gray-600">
                              {item.quantity}x {item.product.name}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div>
                      <label className="text-sm font-medium text-gray-700">Payment</label>
                      <p className="mt-1 text-sm text-gray-900">
                        Method: <span className="capitalize">{order.payment_method.replace('_', ' ')}</span>
                      </p>
                      <p className="text-sm text-gray-900">
                        Total: <span className="font-semibold">{formatCurrency(order.total)}</span>
                      </p>
                    </div>

                    <div>
                      <label className="text-sm font-medium text-gray-700">Status</label>
                      <Select
                        value={order.status}
                        onChange={(e) => handleUpdateStatus(order.id, e.target.value)}
                        options={[
                          { value: 'pending', label: 'Pending' },
                          { value: 'processing', label: 'Processing' },
                          { value: 'shipped', label: 'Shipped' },
                          { value: 'delivered', label: 'Delivered' },
                          { value: 'cancelled', label: 'Cancelled' }
                        ]}
                        className="mt-1"
                      />
                    </div>

                    <div>
                      <label className="text-sm font-medium text-gray-700">Tracking</label>
                      <Input
                        value={order.tracking_number || ''}
                        onChange={(e) => handleUpdateTrackingNumber(order.id, e.target.value)}
                        placeholder="Enter tracking number"
                        className="mt-1"
                      />
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  );
};

export default AdminOrdersPage;