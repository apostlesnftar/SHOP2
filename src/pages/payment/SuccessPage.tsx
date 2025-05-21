import React, { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { CheckCircle, ArrowRight, Package, ShoppingBag } from 'lucide-react';
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
  const [orderDetails, setOrderDetails] = useState<any | null>(null); // Store order details
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const processPayment = async () => {
      try {
        setIsLoading(true);
        
        const shareId = searchParams.get('share');
        if (!shareId) {
          throw new Error('Share ID is missing');
        }

        // 查询共享订单
        const { data: orderData, error: orderError } = await supabase
          .from('shared_orders')
          .select('*')
          .eq('share_id', shareId)
          .eq('payment_status', 'completed')  // 确保支付状态是 completed
          .single();  // 假设每个 share_id 只有一个订单

        if (orderError) {
          throw orderError;
        }

        if (!orderData) {
          throw new Error('Shared order not found or already processed');
        }

        setOrderDetails(orderData);
        setOrderNumber(orderData.order_number);
        clearCart(); // Clear the cart after successful payment

        toast.success('Payment successful!');
      } catch (err) {
        console.error('Error processing payment success:', err);
        setError(err instanceof Error ? err.message : 'An error occurred');
        toast.error('There was a problem processing your payment');
      } finally {
        setIsLoading(false);
      }
    };
    
    processPayment();
  }, [searchParams, clearCart]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-16 text-center">
        <div className="flex flex-col items-center justify-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"></div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Processing your payment</h2>
          <p className="text-gray-600">Please wait while we confirm your payment...</p>
        </div>
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="container mx-auto px-4 py-16 text-center">
        <div className="flex flex-col items-center justify-center">
          <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center text-red-600 mb-4">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Payment Error</h2>
          <p className="text-gray-600 mb-6">{error}</p>
          <Button onClick={() => navigate('/cart')}>
            Return to Cart
          </Button>
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
          <p className="text-gray-600 mb-6">
            Thank you for your purchase. Your order has been confirmed.
          </p>
          
          {orderDetails && (
            <div className="bg-gray-50 rounded-lg p-4 mb-6">
              <p className="text-gray-700">
                Order Number: <span className="font-semibold">{orderNumber}</span>
              </p>
              <p className="text-gray-700">Order Total: <span className="font-semibold">${orderDetails.total}</span></p>
            </div>
          )}
          
          <Button onClick={() => navigate('/')}>
            Return to Home
          </Button>
        </CardContent>
      </Card>
    </div>
  );
};

export default PaymentSuccessPage;
