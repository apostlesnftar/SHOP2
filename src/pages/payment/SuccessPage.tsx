import React, { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { CheckCircle } from 'lucide-react';
import { Card, CardContent } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import { supabase } from '../../lib/supabase';
import { toast } from 'react-hot-toast';
import { useCartStore } from '../../store/cart-store';

const PaymentSuccessPage: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { clearCart } = useCartStore();

  const [isLoading, setIsLoading] = useState(true);
  const [orderNumber, setOrderNumber] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const verifyPaymentStatus = async () => {
      setIsLoading(true);
      try {
        const shareId = searchParams.get('share');
        if (!shareId) {
          throw new Error('Missing share ID');
        }

        // 正确查询 shared_orders 和关联的 orders 表，获取 order_number
        const { data, error } = await supabase
          .from('shared_orders')
          .select('status, orders(order_number)')
          .eq('share_id', shareId)
          .single();

        if (error) throw error;
        if (!data || data.status !== 'completed') {
          throw new Error('Payment not completed or invalid');
        }

        setOrderNumber(data.orders.order_number);
        clearCart();
        toast.success('Payment confirmed!');
      } catch (err) {
        console.error('Error confirming payment:', err);
        setError(err instanceof Error ? err.message : 'An error occurred');
      } finally {
        setIsLoading(false);
      }
    };

    verifyPaymentStatus();
  }, [searchParams, clearCart]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-16 text-center">
        <div className="flex flex-col items-center justify-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"></div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Confirming your payment…</h2>
          <p className="text-gray-600">Please wait while we verify the payment.</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto px-4 py-16 text-center">
        <div className="flex flex-col items-center justify-center">
          <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center text-red-600 mb-4">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Payment Error</h2>
          <p className="text-gray-600 mb-6">{error}</p>
          <Button onClick={() => navigate('/cart')}>Return to Cart</Button>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-16">
      <Card className="max-w-lg mx-auto">
        <CardContent className="p-8 text-center">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center text-green-600 mx-auto mb-6">
            <CheckCircle className="h-8 w-8" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Payment Successful!</h1>
          <p className="text-gray-600 mb-6">Thank you for your purchase. Your order has been confirmed.</p>
          {orderNumber && (
            <div className="bg-gray-50 rounded-lg p-4 mb-6">
              <p className="text-gray-700">
                Order Number: <span className="font-semibold">{orderNumber}</span>
              </p>
            </div>
          )}
          <Button onClick={() => navigate('/')}>Go to Home</Button>
        </CardContent>
      </Card>
    </div>
  );
};

export default PaymentSuccessPage;
