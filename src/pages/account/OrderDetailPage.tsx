import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ChevronRight, Package, MapPin, Truck, Clock } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Badge from '../../components/ui/Badge';
import { formatCurrency, formatDate } from '../../lib/utils';
import { supabase } from '../../lib/supabase';
import { Order } from '../../types';

const statusColors = {
  pending: 'warning',
  processing: 'primary',
  shipped: 'secondary',
  delivered: 'success',
  cancelled: 'danger'
} as const;

const OrderDetailPage: React.FC = () => {
  const { id } = useParams();
  const [order, setOrder] = useState<Order | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchOrder = async () => {
      if (!id) return;

      try {
        const { data, error } = await supabase
          .from('orders')
          .select(`
            *,
            order_items (
              *,
              product:products (*)
            ),
            shipping_address:addresses (*)
          `)
          .eq('id', id)
          .single();

        if (error) throw error;
        if (!data) throw new Error('Order not found');

        setOrder(data);
      } catch (err) {
        console.error('Error fetching order:', err);
        setError(err instanceof Error ? err.message : 'Failed to load order');
      } finally {
        setIsLoading(false);
      }
    };

    fetchOrder();
  }, [id]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            <div className="h-32 bg-gray-200 rounded"></div>
            <div className="h-48 bg-gray-200 rounded"></div>
          </div>
        </div>
      </div>
    );
  }

  if (error || !order) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center">
          <Package className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Order Not Found</h2>
          <p className="text-gray-600 mb-6">{error || 'Unable to load order details'}</p>
          <Link
            to="/orders"
            className="text-blue-600 hover:text-blue-800 font-medium"
          >
            Back to Orders
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Breadcrumb */}
      <div className="flex items-center text-sm text-gray-500 mb-6">
        <Link to="/orders" className="hover:text-blue-600">Orders</Link>
        <ChevronRight className="h-4 w-4 mx-1" />
        <span className="text-gray-900 font-medium">Order #{order.order_number}</span>
      </div>

      {/* Order Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 mb-1">
            Order #{order.order_number}
          </h1>
          <p className="text-gray-600">
            Placed on {formatDate(order.created_at)}
          </p>
        </div>
        <div className="mt-4 md:mt-0">
          <Badge
            variant={statusColors[order.status as keyof typeof statusColors]}
            size="md"
            className="capitalize"
          >
            {order.status}
          </Badge>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Order Items */}
        <div className="lg:col-span-2">
          <Card>
            <CardHeader>
              <CardTitle>Order Items</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {order.order_items?.map((item) => (
                  <div key={item.id} className="flex border-b border-gray-200 pb-4 last:border-0 last:pb-0">
                    <div className="h-24 w-24 flex-shrink-0 overflow-hidden rounded-md border border-gray-200">
                      <img
                        src={item.product.images[0]}
                        alt={item.product.name}
                        className="h-full w-full object-cover object-center"
                      />
                    </div>
                    <div className="ml-4 flex flex-1 flex-col">
                      <div>
                        <div className="flex justify-between text-base font-medium text-gray-900">
                          <h3>
                            <Link to={`/products/${item.product.id}`}>
                              {item.product.name}
                            </Link>
                          </h3>
                          <p className="ml-4">{formatCurrency(item.price * item.quantity)}</p>
                        </div>
                        <p className="mt-1 text-sm text-gray-500">{item.product.description}</p>
                      </div>
                      <div className="flex flex-1 items-end justify-between text-sm">
                        <p className="text-gray-500">Qty {item.quantity}</p>
                        <div className="flex">
                          <Link
                            to={`/products/${item.product.id}`}
                            className="text-blue-600 hover:text-blue-800"
                          >
                            View Product
                          </Link>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Order Summary and Shipping */}
        <div className="space-y-6">
          {/* Order Summary */}
          <Card>
            <CardHeader>
              <CardTitle>Order Summary</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Subtotal</span>
                  <span className="font-medium">{formatCurrency(order.subtotal)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Shipping</span>
                  <span className="font-medium">{formatCurrency(order.shipping)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Tax</span>
                  <span className="font-medium">{formatCurrency(order.tax)}</span>
                </div>
                <div className="border-t border-gray-200 pt-2 flex justify-between">
                  <span className="font-medium">Total</span>
                  <span className="font-bold">{formatCurrency(order.total)}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Shipping Information */}
          <Card>
            <CardHeader>
              <div className="flex items-center">
                <MapPin className="h-5 w-5 text-gray-400 mr-2" />
                <CardTitle>Shipping Address</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              {order.shipping_address ? (
                <div className="text-sm space-y-1">
                  <p className="font-medium text-gray-900">{order.shipping_address.name}</p>
                  <p className="text-gray-600">{order.shipping_address.address_line1}</p>
                  {order.shipping_address.address_line2 && (
                    <p className="text-gray-600">{order.shipping_address.address_line2}</p>
                  )}
                  <p className="text-gray-600">
                    {order.shipping_address.city}, {order.shipping_address.state} {order.shipping_address.postal_code}
                  </p>
                  <p className="text-gray-600">{order.shipping_address.country}</p>
                  <p className="text-gray-600 mt-2">{order.shipping_address.phone}</p>
                </div>
              ) : (
                <p className="text-sm text-gray-500">No shipping address available</p>
              )}
            </CardContent>
          </Card>

          {/* Shipping Status */}
          <Card>
            <CardHeader>
              <div className="flex items-center">
                <Truck className="h-5 w-5 text-gray-400 mr-2" />
                <CardTitle>Shipping Status</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex items-center">
                  <Clock className="h-5 w-5 text-gray-400 mr-2" />
                  <div>
                    <p className="text-sm font-medium text-gray-900">Status</p>
                    <p className="text-sm text-gray-600 capitalize">{order.status}</p>
                  </div>
                </div>
                {order.tracking_number && (
                  <div>
                    <p className="text-sm font-medium text-gray-900">Tracking Number</p>
                    <p className="text-sm text-gray-600">{order.tracking_number}</p>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default OrderDetailPage;