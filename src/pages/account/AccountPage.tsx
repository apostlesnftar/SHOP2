import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card } from '../../components/ui/Card';
import { useAuthStore } from '../../store/auth-store';
import { formatDate } from '../../lib/utils';
import Button from '../../components/ui/Button';
import { supabase } from '../../lib/supabase';

interface AccountStats {
  orderCount: number;
  totalSpent: number;
  lastOrderDate: string | null;
}

export default function AccountPage() {
  const { user } = useAuthStore();
  const navigate = useNavigate();
  const [stats, setStats] = useState<AccountStats>({
    orderCount: 0,
    totalSpent: 0,
    lastOrderDate: null
  });
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchAccountStats = async () => {
      try {
        // Get order statistics
        const { data: orderStats, error: orderError } = await supabase
          .from('orders')
          .select('id, total, created_at')
          .eq('user_id', user?.id)
          .order('created_at', { ascending: false });

        if (orderError) throw orderError;

        setStats({
          orderCount: orderStats?.length || 0,
          totalSpent: orderStats?.reduce((sum, order) => sum + order.total, 0) || 0,
          lastOrderDate: orderStats?.[0]?.created_at || null
        });
      } catch (error) {
        console.error('Error fetching account stats:', error);
      } finally {
        setIsLoading(false);
      }
    };

    if (user) {
      fetchAccountStats();
    }
  }, [user]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-8"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="h-48 bg-gray-200 rounded"></div>
            <div className="h-48 bg-gray-200 rounded"></div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">My Account</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">Profile Information</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">Name</label>
              <p className="mt-1 text-gray-900">{user?.fullName || user?.username}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Email</label>
              <p className="mt-1 text-gray-900">{user?.email}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Account Type</label>
              <p className="mt-1 text-gray-900 capitalize">{user?.role}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Member Since</label>
              <p className="mt-1 text-gray-900">{formatDate(user?.createdAt || '')}</p>
            </div>
            <Button
              variant="outline"
              onClick={() => navigate('/account/edit')}
              className="mt-4"
            >
              Edit Profile
            </Button>
          </div>
        </Card>
        
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">Account Summary</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">Total Orders</label>
              <p className="mt-1 text-gray-900">{stats.orderCount} orders placed</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Total Spent</label>
              <p className="mt-1 text-gray-900">
                ${stats.totalSpent.toFixed(2)}
              </p>
            </div>
            {stats.lastOrderDate && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Last Order</label>
                <p className="mt-1 text-gray-900">{formatDate(stats.lastOrderDate)}</p>
              </div>
            )}
            <Button
              onClick={() => navigate('/orders')}
              className="mt-4"
            >
              View Orders
            </Button>
          </div>
        </Card>
      </div>
    </div>
  );
}