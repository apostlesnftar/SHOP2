import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { ExternalLink, ShieldCheck, AlertTriangle, Clock, CreditCard } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/Card';
import Button from '../components/ui/Button';
import { formatCurrency, formatDate } from '../lib/utils';
import { SharedOrder } from '../types';
import { toast } from 'react-hot-toast';
import { getSharedOrderByShareId, processSharedOrderPayment } from '../services/order-service';
import { supabase } from '../lib/supabase';
import Badge from '../components/ui/Badge';
import { createAcaciaPayOrder } from '../lib/payment/utils/acacia-pay';
import { useAuthStore } from '../store/auth-store';

const SharedOrderPage: React.FC = () => {
  const { shareId } = useParams<{ shareId: string }>();
  const navigate = useNavigate();
  const [order, setOrder] = useState<SharedOrder | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState('');
  const [availablePaymentMethods, setAvailablePaymentMethods] = useState<Array<{
    method: string;
    provider: string;
    gateway_id: string | null;
    test_mode: boolean;
    display_name?: string;
    icon_url?: string;
  }>>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [timeLeft, setTimeLeft] = useState<string>('');
  const { user } = useAuthStore();

  useEffect(() => {
    fetchPaymentMethods();
  }, []);

  const fetchPaymentMethods = async () => {
    try {
      const { data, error } = await supabase.rpc('get_shared_order_payment_methods');
      
      if (error) throw error;
      
      // Only filter out friend_payment as it's not applicable for shared orders
      const filteredMethods = (data || []).filter(method => method.method !== 'friend_payment');
      
      setAvailablePaymentMethods(filteredMethods);
      
      // Set the first available method as selected if there are any methods
      if (filteredMethods.length > 0) {
        setSelectedPaymentMethod(filteredMethods[0].method);
      }
    } catch (error) {
      console.error('Error fetching payment methods:', error);
      toast.error('Failed to load payment methods');
    }
  };

  useEffect(() => {
    const fetchSharedOrder = async () => {
      setIsLoading(true);
      try {
        if (!shareId) {
          throw new Error('Invalid share ID');
        }

        const sharedOrder = await getSharedOrderByShareId(shareId);
        
        if (!sharedOrder) {
          throw new Error('Shared order not found');
        }
        
        setOrder(sharedOrder);
      } catch (err) {
        console.error('Error fetching shared order:', err);
        setError('Failed to load the shared order');
        toast.error('Failed to load the shared order');
      } finally {
        setIsLoading(false);
      }
    };

    if (shareId) {
      fetchSharedOrder();
    }
  }, [shareId]);

  useEffect(() => {
    if (!order) return;

    const updateTimeLeft = () => {
      const now = new Date().getTime();
      const expiresAt = new Date(order.expiresAt).getTime();
      const diff = expiresAt - now;

      if (diff <= 0) {
        setTimeLeft('Expired');
        return;
      }

      const hours = Math.floor(diff / (1000 * 60 * 60));
      const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
      setTimeLeft(`${hours}h ${minutes}m`);
    };

    updateTimeLeft();
    const interval = setInterval(updateTimeLeft, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [order]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-2xl mx-auto">
          <Card>
            <CardContent className="p-6">
              <div className="animate-pulse space-y-4">
                <div className="h-8 bg-gray-200 rounded w-3/4"></div>
                <div className="space-y-3">
                  <div className="h-4 bg-gray-200 rounded"></div>
                  <div className="h-4 bg-gray-200 rounded w-5/6"></div>
                </div>
                <div className="h-32 bg-gray-200 rounded"></div>
                <div className="h-10 bg-gray-200 rounded"></div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  if (error || !order) {
    return (
      <div className="container mx-auto px-4 py-12">
        <div className="max-w-md mx-auto text-center">
          <AlertTriangle className="h-12 w-12 text-red-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Order Not Found</h1>
          <p className="text-gray-600 mb-6">
            This shared order link is invalid or has expired.
          </p>
          <Link to="/">
            <Button>Return Home</Button>
          </Link>
        </div>
      </div>
    );
  }

  const isExpired = new Date(order.expiresAt) < new Date();
  const isPaid = order.paymentStatus === 'completed';

  if (isExpired || isPaid) {
    return (
      <div className="container mx-auto px-4 py-12">
        <div className="max-w-md mx-auto text-center">
          <AlertTriangle className="h-12 w-12 text-amber-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            {isPaid ? 'Order Already Paid' : 'Link Expired'}
          </h1>
          <p className="text-gray-600 mb-6">
            {isPaid
              ? 'This order has already been paid for.'
              : 'This shared order link has expired.'}
          </p>
          <Link to="/">
            <Button>Return Home</Button>
          </Link>
        </div>
      </div>
    );
  }

  const handlePayment = async () => {
    if (!selectedPaymentMethod) {
      toast.error('Please select a payment method');
      return;
    }
    // Find the selected payment method in the available methods
    const selectedMethod = availablePaymentMethods.find(
      method => method.method === selectedPaymentMethod
    );

    if (!selectedMethod) {
      toast.error(`Invalid payment method: ${selectedPaymentMethod}`);
      return;
    }

    setIsProcessing(true);
    try {
      // Special handling for Acacia Pay
      if (selectedMethod.method === 'acacia_pay') {
        console.log('Processing Acacia Pay payment');
        const result = await createAcaciaPayOrder(
          order.total,
          `S${shareId}`,
          {
            successUrl: `${window.location.origin}/payment/success?share=${shareId}`,
            subject: 'Shared Order Payment',
            description: `Payment for shared order ${shareId}`
          }
        );
        
        if (!result.success) {
          throw new Error(result.error || 'Failed to create Acacia Pay order');
        }
        
        // Redirect to Acacia Pay payment page
        window.location.href = result.paymentUrl as string;
        return;
      }

      // Process payment using Supabase RPC function with explicit null for referrer_id
      // This ensures we're not passing an ambiguous column reference
      const { data, error } = await supabase.rpc('process_friend_payment', {
        p_share_id: shareId,
        p_payment_method: selectedPaymentMethod,
        p_referrer_id: null // Explicitly pass null to avoid ambiguity
      });

      if (error) {
        console.error('Payment RPC error:', error);
        throw error;
      }
      
      if (!data || !data.success) {
        console.error('Payment processing failed:', data?.error || 'Unknown error', data);
        throw new Error(data?.error || 'Payment processing failed');
      }

      toast.success('Payment processed successfully!');
      navigate('/payment/success');
    } catch (err) {
      console.error('Payment error:', err);
      toast.error(err instanceof Error ? err.message : 'Failed to process payment');
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-2xl mx-auto">
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Shared Order Details</CardTitle>
              <div className="flex items-center text-sm text-gray-500">
                <Clock className="h-4 w-4 mr-1" />
                <span>Expires in: {timeLeft}</span>
              </div>
            </div>
          </CardHeader>
          
          <CardContent className="p-6">
            <div className="space-y-6">
              {/* Order Items */}
              <div>
                <h3 className="font-medium text-gray-900 mb-3">Order Items</h3>
                <div className="divide-y divide-gray-200">
                  {order.items.map((item) => (
                    <div key={item.id} className="py-4 flex items-center">
                      <img
                        src={item.product.images[0]}
                        alt={item.product.name}
                        className="w-16 h-16 object-cover rounded-md"
                      />
                      <div className="ml-4 flex-grow">
                        <h4 className="font-medium text-gray-900">
                          {item.product.name}
                        </h4>
                        <p className="text-sm text-gray-600">
                          Quantity: {item.quantity}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="font-medium text-gray-900">
                          {formatCurrency(item.price * item.quantity)}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Total */}
              <div className="border-t border-gray-200 pt-4">
                <div className="flex justify-between items-center">
                  <span className="text-lg font-semibold text-gray-900">
                    Total Amount
                  </span>
                  <span className="text-xl font-bold text-gray-900">
                    {formatCurrency(order.total)}
                  </span>
                </div>
              </div>

              {/* Security Notice */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div className="flex items-start">
                  <ShieldCheck className="h-5 w-5 text-blue-500 mt-0.5 mr-3" />
                  <div>
                    <h4 className="font-medium text-blue-900">Secure Payment</h4>
                    <p className="text-sm text-blue-700">
                      This is a secure payment link valid until{' '}
                      {formatDate(order.expiresAt)}
                    </p>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="space-y-6">
                <div>
                  <h3 className="font-medium text-gray-900 mb-3">Payment Method</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    {availablePaymentMethods && availablePaymentMethods.length > 0 ? (
                      availablePaymentMethods.map((method) => (
                      <button
                        key={method.method}
                        type="button"
                        className={`border rounded-lg p-4 flex items-center justify-center gap-2 ${
                          selectedPaymentMethod === method.method 
                            ? 'border-blue-600 bg-blue-50' 
                            : 'border-gray-200 hover:border-gray-300'
                        }`}
                        onClick={() => setSelectedPaymentMethod(method.method)}
                      >
                        {method.icon_url ? (
                          <img 
                            src={method.icon_url} 
                            alt={method.display_name || method.method.replace(/_/g, ' ')}
                            className="h-5 w-5 object-contain"
                          />
                        ) : method.method === 'credit_card' ? (
                          <CreditCard className="h-5 w-5" />
                        ) : method.method === 'paypal' ? (
                          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M20.0704 7.13987C20.1656 6.64155 20.1656 6.12543 20.075 5.63471C19.6626 3.62478 17.9613 2.58594 15.8004 2.58594H10.7033C10.3534 2.58594 10.0499 2.84143 9.9964 3.18822L7.95749 15.638C7.91962 15.8935 8.11772 16.125 8.37614 16.125H11.2193L10.8882 18.1728C10.8551 18.3981 11.035 18.599 11.2626 18.599H13.8518C14.1564 18.599 14.4215 18.3666 14.4695 18.0644L14.4751 18.024L14.9431 15.3176L14.9501 15.2629C14.9981 14.9607 15.2632 14.7284 15.5678 14.7284H15.9773C18.3431 14.7284 20.197 13.7391 20.6946 10.9778C20.9032 9.84666 20.7966 8.89903 20.0704 7.13987Z" fill="#009CDE"/>
                            <path d="M20.0704 7.13987C20.1656 6.64155 20.1656 6.12543 20.075 5.63471C19.6626 3.62478 17.9613 2.58594 15.8004 2.58594H10.7033C10.3534 2.58594 10.0499 2.84143 9.9964 3.18822L7.95749 15.638C7.91962 15.8935 8.11772 16.125 8.37614 16.125H11.2193L11.9625 11.8151L11.9391 11.9698C11.9926 11.623 12.2886 11.3675 12.6385 11.3675H14.1377C16.8787 11.3675 19.0113 10.2316 19.5816 7.0277C19.6092 6.91305 19.6334 6.80274 19.6542 6.69556C19.8206 6.83447 19.9576 6.9814 20.0704 7.13987Z" fill="#012169"/>
                            <path d="M10.4044 6.70067C10.4416 6.49632 10.5636 6.32068 10.7294 6.21038C10.8044 6.16435 10.8884 6.13867 10.9783 6.13867H15.1522C15.6522 6.13867 16.1201 6.17583 16.5473 6.25481C16.6546 6.27507 16.7592 6.29883 16.8609 6.3261C16.9626 6.35337 17.0613 6.38414 17.1567 6.4184C17.2044 6.43554 17.251 6.4537 17.2969 6.47289C17.3887 6.51127 17.4762 6.55317 17.5592 6.59859C19.7526 7.54927 20.1919 9.72243 19.5817 7.02772C19.0115 10.2317 16.8789 11.3675 14.1378 11.3675H12.6386C12.2887 11.3675 11.9928 11.6231 11.9393 11.9698L11.2194 16.125H8.37618C8.11777 16.125 7.91967 15.8935 7.95754 15.638L9.9964 3.18824C10.05 2.84146 10.3535 2.58594 10.7033 2.58594H15.8005C17.9613 2.58594 19.6627 3.62478 20.0751 5.63471C20.1656 6.12543 20.1656 6.64154 20.0705 7.13987C19.9576 6.98141 19.8207 6.83448 19.6543 6.69557C19.498 6.56408 19.3162 6.44591 19.1107 6.34103C18.1594 5.93042 16.864 5.73438 15.1522 5.73438H11.1661C10.9932 5.73438 10.8356 5.81453 10.7284 5.94385C10.6212 6.07316 10.5789 6.24445 10.6143 6.41298L11.9626 11.8151L10.4044 6.70067Z" fill="#003087"/>
                          </svg>
                        ) : (
                          <div className="h-5 w-5 bg-gray-200 rounded-full"></div>
                        )}
                        <span>{method.display_name || method.method.replace('_', ' ')}</span>
                        {method.test_mode && (
                          <Badge variant="warning" size="sm">Test</Badge>
                        )}
                      </button>
                      ))
                    ) : (
                      <div className="col-span-2 text-center p-4 bg-gray-50 rounded-lg">
                        <p className="text-gray-500">No payment methods available</p>
                      </div>
                    )}
                  </div>
                </div>
                
                <Button
                  className="w-full"
                  size="lg"
                  onClick={handlePayment}
                  isLoading={isProcessing || isLoading}
                  disabled={!selectedPaymentMethod || availablePaymentMethods.length === 0}
                >
                  Pay {formatCurrency(order.total)}
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default SharedOrderPage;