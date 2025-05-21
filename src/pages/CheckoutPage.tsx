import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { 
  CreditCard, Users, Check, MapPin, ChevronRight, ChevronDown, 
  Plus, ChevronUp, Clock, AlertCircle, Share2,
  Copy, ExternalLink, X, ArrowRight
} from 'lucide-react';
import { toast } from 'react-hot-toast';
import { supabase } from '../lib/supabase';
import { createAcaciaPayOrder } from '../lib/payment/utils/acacia-pay';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/Card';
import { Badge } from '../components/ui/Badge';
import Button from '../components/ui/Button';
import Input from '../components/ui/Input';
import Select from '../components/ui/Select';
import { useCartStore } from '../store/cart-store';
import { useAuthStore } from '../store/auth-store';
import { formatCurrency, generateOrderNumber, generateShareId, generateShareableLink } from '../lib/utils';

const CheckoutPage: React.FC = () => {
  const navigate = useNavigate();
  const { items, getSubtotal, clearCart } = useCartStore();
  const { user, isAuthenticated } = useAuthStore();
  
  const [addresses, setAddresses] = useState<any[]>([]);
  const [isLoadingAddresses, setIsLoadingAddresses] = useState(true);
  
  useEffect(() => {
    const loadAddresses = async () => {
      if (!user?.id) return;
      
      try {
        const { data, error } = await supabase
          .from('addresses')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        setAddresses(data || []);
        
        const defaultAddress = data?.find(addr => addr.is_default);
        if (defaultAddress) {
          setSelectedAddressId(defaultAddress.id);
        }
      } catch (error) {
        console.error('Error loading addresses:', error);
        toast.error('Failed to load addresses');
      } finally {
        setIsLoadingAddresses(false);
      }
    };
    
    loadAddresses();
  }, [user?.id]);
  
  const [activeSection, setActiveSection] = useState('shipping');
  const [isProcessing, setIsProcessing] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState('credit_card');
  const [isGroupPayment, setIsGroupPayment] = useState(false);
  const [availablePaymentMethods, setAvailablePaymentMethods] = useState<Array<{
    method: string;
    provider: string;
    gateway_id: string | null;
    test_mode: boolean;
  }>>([]);
  const [groupPaymentEmails, setGroupPaymentEmails] = useState(['']);
  const [selectedAddressId, setSelectedAddressId] = useState<string | null>(null);
  const [shareModalOpen, setShareModalOpen] = useState(false);
  const [shareLink, setShareLink] = useState('');
  const [formData, setFormData] = useState({
    name: user?.username || '',
    email: user?.email || '',
    phone: '',
    addressLine1: '',
    addressLine2: '',
    city: '',
    state: '',
    postalCode: '',
    country: 'United States',
    cardNumber: '',
    cardName: '',
    expiryDate: '',
    cvv: '',
  });
  
  const subtotal = getSubtotal();
  const shippingCost = subtotal > 50 ? 0 : 10;
  const taxRate = 0.08;
  const taxAmount = subtotal * taxRate;
  const total = subtotal + shippingCost + taxAmount;
  
  useEffect(() => {
    fetchPaymentMethods();
  }, []);

  const fetchPaymentMethods = async () => {
    try {
      const { data, error } = await supabase.rpc('get_available_payment_methods');
      
      if (error) throw error;
      
      setAvailablePaymentMethods(data || []);
      
      if (data && data.length > 0) {
        setPaymentMethod(data[0].method);
      }
    } catch (error) {
      console.error('Error fetching payment methods:', error);
      toast.error('Failed to load payment methods');
    }
  };

  if (items.length === 0) {
    navigate('/cart');
    return null;
  }
  
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };
  
  const handleSectionToggle = (section: string) => {
    if (section === 'payment' && activeSection === 'shipping') {
      if (!selectedAddressId && !formData.addressLine1) {
        toast.error('Please provide a shipping address');
        return;
      }
      
      if (!selectedAddressId) {
        if (!formData.addressLine1 || !formData.city || !formData.state || !formData.postalCode) {
          toast.error('Please provide a complete shipping address');
          return;
        }
      }
    }
    
    if (section === 'review' && activeSection === 'payment') {
      if (!paymentMethod) {
        toast.error('Please select a payment method');
        return;
      }
      
      if (paymentMethod === 'credit_card') {
        if (!formData.cardNumber || !formData.cardName || !formData.expiryDate || !formData.cvv) {
          toast.error('Please fill in all card details');
          return;
        }
      }
    }
    
    setActiveSection(section);
  };
  
  const handleAddressSelect = (addressId: string) => {
    setSelectedAddressId(addressId);
    setFormData(prev => ({
      ...prev,
      addressLine1: '',
      addressLine2: '',
      city: '',
      state: '',
      postalCode: '',
      country: 'United States',
    }));
  };
  
  const handleGroupPaymentToggle = () => {
    setIsGroupPayment(!isGroupPayment);
  };
  
  const handleGroupEmailChange = (index: number, value: string) => {
    const newEmails = [...groupPaymentEmails];
    newEmails[index] = value;
    setGroupPaymentEmails(newEmails);
  };
  
  const handleAddGroupEmail = () => {
    setGroupPaymentEmails([...groupPaymentEmails, '']);
  };
  
  const handleRemoveGroupEmail = (index: number) => {
    const newEmails = [...groupPaymentEmails];
    newEmails.splice(index, 1);
    setGroupPaymentEmails(newEmails);
  };
  
  const handleShareOrder = () => {
    const shareId = generateShareId();
    const link = generateShareableLink(shareId);
    setShareLink(link);
    setShareModalOpen(true);
  };

  const handleCopyLink = async () => {
    try {
      await navigator.clipboard.writeText(shareLink);
      toast.success('Link copied to clipboard!');
    } catch (err) {
      toast.error('Failed to copy link');
    }
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsProcessing(true);
    
    if (!selectedAddressId && !formData.addressLine1) {
      toast.error('Please provide a shipping address');
      setIsProcessing(false);
      return;
    }
    
    if (!paymentMethod) {
      toast.error('Please select a payment method');
      setIsProcessing(false);
      return;
    }

    const isValidPaymentMethod = availablePaymentMethods.some(method => method.method === paymentMethod);
    if (!isValidPaymentMethod) {
      toast.error(`Invalid payment method: ${paymentMethod}`);
      setIsProcessing(false);
      return;
    }
    
    if (paymentMethod === 'friend_payment' && activeSection !== 'review') {
      handleSectionToggle('review');
      setIsProcessing(false);
      return;
    }
    
    try {
      // Handle Acacia Pay payment method
      if (paymentMethod === 'acacia_pay') {
        return await handleAcaciaPayment();
      }
      
      const { data: products, error: inventoryError } = await supabase
        .from('products')
        .select('id, inventory')
        .in('id', items.map(item => item.productId));

      if (inventoryError) throw inventoryError;

      const inventoryMap = new Map(products?.map(p => [p.id, p.inventory]));

      const inventoryViolation = items.find(item => {
        const availableInventory = inventoryMap.get(item.productId) || 0;
        return item.quantity > availableInventory;
      });

      if (inventoryViolation) {
        const availableInventory = inventoryMap.get(inventoryViolation.productId) || 0;
        toast.error(
          `Sorry, only ${availableInventory} units of "${inventoryViolation.product.name}" are available.`
        );
        setIsProcessing(false);
        return;
      }

      const orderItems = items.map(item => ({
        product_id: item.product.id,
        quantity: item.quantity,
        price: item.product.discount 
          ? item.product.price * (1 - item.product.discount / 100) 
          : item.product.price
      }));
      
      let shippingAddressId = selectedAddressId;
      
      if (!selectedAddressId) {
        const { data: newAddress, error: addressError } = await supabase
          .from('addresses')
          .insert({
            user_id: user?.id,
            name: formData.name,
            address_line1: formData.addressLine1,
            address_line2: formData.addressLine2 || null,
            city: formData.city,
            state: formData.state,
            postal_code: formData.postalCode,
            country: formData.country,
            phone: formData.phone
          })
          .select()
          .single();
    
        if (addressError) throw addressError;
        if (!newAddress) throw new Error('Failed to create shipping address');
        
        shippingAddressId = newAddress.id;
      }
      
      if (!shippingAddressId) {
        throw new Error('Invalid shipping address');
      }

      try {
        const { data: order, error: orderError } = await supabase
          .from('orders')
          .insert({
            user_id: user?.id,
            order_number: generateOrderNumber(),
            shipping_address_id: shippingAddressId,
            payment_method: paymentMethod,
            payment_status: 'pending',
            status: 'pending',
            subtotal: subtotal,
            tax: taxAmount,
            shipping: shippingCost,
            total: total
          })
          .select()
          .single();
      
        if (orderError) throw orderError;
        if (!order) throw new Error('Failed to create order');

        const { error: itemsError } = await supabase
          .from('order_items')
          .insert(
            orderItems.map(item => ({
              order_id: order.id,
              ...item
            }))
          );

        if (itemsError) throw itemsError;
      
        if (paymentMethod === 'friend_payment') {
          const { data: shareData, error: shareError } = await supabase
            .rpc('share_order', {
              p_order_id: order.id
            });
        
          if (shareError) throw shareError;
          if (!shareData?.success) {
            throw new Error(shareData?.error || 'Failed to create shared order');
          }
        
          const shareLink = generateShareableLink(shareData?.share_id);
          setShareLink(shareLink);
          setShareModalOpen(true);
        
          clearCart();
          
          toast.success('Order created! Share the payment link with your friends to complete the payment.');
        } else {
          const { error: updateError } = await supabase
            .from('orders')
            .update({
              payment_status: 'completed',
              status: 'processing'
            })
            .eq('id', order.id);
        
          if (updateError) throw updateError;
        
          clearCart();
          navigate(`/order-success?order=${order.order_number}`);
          
          toast.success('Order placed successfully!');
        }
      } catch (error) {
        console.error('Checkout error:', error);
        toast.error(error instanceof Error ? error.message : 'Failed to process order');
      }
    } catch (error) {
      console.error('Checkout error:', error);
      toast.error(error instanceof Error ? error.message : 'Failed to process order');
    } finally {
      setIsProcessing(false);
    }
  };

  // Handle Acacia Pay payment
  const handleAcaciaPayment = async () => {
    try {
      // Validate shipping address
      if (!selectedAddressId && !formData.addressLine1) {
        toast.error('Please provide a shipping address');
        setIsProcessing(false);
        return;
      }
      
      // Create shipping address if needed
      let shippingAddressId = selectedAddressId;
      
      if (!selectedAddressId) {
        const { data: newAddress, error: addressError } = await supabase
          .from('addresses')
          .insert({
            user_id: user?.id,
            name: formData.name,
            address_line1: formData.addressLine1,
            address_line2: formData.addressLine2 || null,
            city: formData.city,
            state: formData.state,
            postal_code: formData.postalCode,
            country: formData.country,
            phone: formData.phone
          })
          .select()
          .single();
    
        if (addressError) throw addressError;
        if (!newAddress) throw new Error('Failed to create shipping address');
        
        shippingAddressId = newAddress.id;
      }
      
      // Create order with pending status
      const { data: order, error: orderError } = await supabase
        .from('orders')
        .insert({
          user_id: user?.id,
          order_number: generateOrderNumber(),
          shipping_address_id: shippingAddressId,
          payment_method: 'acacia_pay',
          payment_status: 'pending',
          status: 'pending',
          subtotal: subtotal,
          tax: taxAmount,
          shipping: shippingCost,
          total: total
        })
        .select()
        .single();
    
      if (orderError) throw orderError;
      if (!order) throw new Error('Failed to create order');

      // Create order items
      const orderItems = items.map(item => ({
        order_id: order.id,
        product_id: item.product.id,
        quantity: item.quantity,
        price: item.product.discount 
          ? item.product.price * (1 - item.product.discount / 100) 
          : item.product.price
      }));

      const { error: itemsError } = await supabase
        .from('order_items')
        .insert(orderItems);

      if (itemsError) throw itemsError;
      
      // Create Acacia Pay order
      const acaciaPayResult = await createAcaciaPayOrder(
        total,
        order.order_number,
        {
          successUrl: `${window.location.origin}/order-success?order=${order.order_number}`,
          notifyUrl: `${window.location.origin}/api/payment/webhook`,
          subject: `Order #${order.order_number}`,
          description: `Payment for order #${order.order_number}`
        }
      );
      
      if (!acaciaPayResult.success) {
        throw new Error(acaciaPayResult.error || 'Failed to create Acacia Pay order');
      }
      
      // Clear cart
      clearCart();
      
      // Redirect to Acacia Pay payment page
      window.location.href = acaciaPayResult.paymentUrl as string;
      
      return true;
    } catch (error) {
      console.error('Acacia Pay error:', error);
      toast.error(error instanceof Error ? error.message : 'Failed to process payment');
      setIsProcessing(false);
      return false;
    }
  };

  const handleCheckout = () => {
    if (activeSection === 'shipping') {
      handleSectionToggle('payment');
    } else if (activeSection === 'payment') {
      handleSectionToggle('review');
    }
  };
  
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Checkout</h1>
        <div className="flex items-center text-sm text-gray-500">
          <Link to="/cart" className="hover:text-blue-600">Cart</Link>
          <ChevronRight className="h-4 w-4 mx-1" />
          <span className="text-gray-900 font-medium">Checkout</span>
        </div>
      </div>
      
      <div className="flex flex-col lg:flex-row gap-8">
        <div className="lg:w-2/3">
          <form onSubmit={handleSubmit}>
            <Card className="mb-6">
              <CardHeader
                className="cursor-pointer"
                onClick={() => handleSectionToggle('shipping')}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center">
                    <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-3">
                      <MapPin className="h-5 w-5" />
                    </div>
                    <CardTitle>Shipping Information</CardTitle>
                  </div>
                  {activeSection === 'shipping' ? (
                    <ChevronUp className="h-5 w-5 text-gray-500" />
                  ) : (
                    <ChevronDown className="h-5 w-5 text-gray-500" />
                  )}
                </div>
              </CardHeader>
              
              {activeSection === 'shipping' && (
                <CardContent>
                  {isAuthenticated && (
                    <div className="mb-6">
                      <h3 className="font-medium text-gray-900 mb-3">Saved Addresses</h3>
                      {isLoadingAddresses ? (
                        <div className="text-gray-600">Loading addresses...</div>
                      ) : addresses.length > 0 ? (
                        <div className="space-y-3">
                          {addresses.map((address) => (
                            <div 
                              key={address.id} 
                              className={`border rounded-lg p-4 cursor-pointer ${
                                selectedAddressId === address.id 
                                  ? 'border-blue-600 bg-blue-50' 
                                  : 'border-gray-200 hover:border-gray-300'
                              }`}
                              onClick={() => handleAddressSelect(address.id)}
                            >
                              <div className="flex items-start justify-between">
                                <div>
                                  <div className="font-medium text-gray-900">{address.name}</div>
                                  <div className="text-gray-600 text-sm mt-1">
                                    {address.address_line1}
                                    {address.address_line2 && `, ${address.address_line2}`}
                                  </div>
                                  <div className="text-gray-600 text-sm">
                                    {address.city}, {address.state} {address.postal_code}
                                  </div>
                                  <div className="text-gray-600 text-sm">{address.country}</div>
                                  <div className="text-gray-600 text-sm mt-1">{address.phone}</div>
                                </div>
                                {selectedAddressId === address.id && (
                                  <Check className="h-5 w-5 text-blue-600" />
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="text-gray-600 mb-4">No saved addresses found.</div>
                      )}
                      
                      <Button 
                        type="button" 
                        variant="outline" 
                        className="w-full mt-3"
                        leftIcon={<Plus className="h-4 w-4" />}
                        onClick={() => {
                          setSelectedAddressId(null);
                          setActiveSection('shipping');
                        }}
                      >
                        Add New Address
                      </Button>
                    </div>
                  )}
                  
                  {(!selectedAddressId || !isAuthenticated) && (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <Input
                        label="Full Name"
                        name="name"
                        value={formData.name}
                        onChange={handleInputChange}
                        required
                      />
                      <Input
                        label="Email"
                        type="email"
                        name="email"
                        value={formData.email}
                        onChange={handleInputChange}
                        required
                      />
                      <Input
                        label="Phone Number"
                        name="phone"
                        value={formData.phone}
                        onChange={handleInputChange}
                        required
                      />
                      <Input
                        label="Address Line 1"
                        name="addressLine1"
                        value={formData.addressLine1}
                        onChange={handleInputChange}
                        required
                      />
                      <Input
                        label="Address Line 2 (Optional)"
                        name="addressLine2"
                        value={formData.addressLine2}
                        onChange={handleInputChange}
                      />
                      <Input
                        label="City"
                        name="city"
                        value={formData.city}
                        onChange={handleInputChange}
                        required
                      />
                      <Input
                        label="State/Province"
                        name="state"
                        value={formData.state}
                        onChange={handleInputChange}
                        required
                      />
                      <Input
                        label="Postal Code"
                        name="postalCode"
                        value={formData.postalCode}
                        onChange={handleInputChange}
                        required
                      />
                      <Select
                        label="Country"
                        name="country"
                        value={formData.country}
                        onChange={handleInputChange}
                        options={[
                          { value: 'United States', label: 'United States' },
                          { value: 'Canada', label: 'Canada' },
                          { value: 'United Kingdom', label: 'United Kingdom' }
                        ]}
                        required
                      />
                    </div>
                  )}
                  
                  <div className="mt-4 flex justify-end">
                    <Button 
                      type="button" 
                      onClick={() => handleSectionToggle('payment')}
                    >
                      Continue to Payment
                    </Button>
                  </div>
                </CardContent>
              )}
            </Card>
            
            <Card className="mb-6">
              <CardHeader
                className="cursor-pointer"
                onClick={() => handleSectionToggle('payment')}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center">
                    <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-3">
                      <CreditCard className="h-5 w-5" />
                    </div>
                    <CardTitle>Payment Information</CardTitle>
                  </div>
                  {activeSection === 'payment' ? (
                    <ChevronUp className="h-5 w-5 text-gray-500" />
                  ) : (
                    <ChevronDown className="h-5 w-5 text-gray-500" />
                  )}
                </div>
              </CardHeader>
              
              {activeSection === 'payment' && (
                <CardContent>
                  <div className="space-y-4">
                    <div>
                      <h3 className="font-medium text-gray-900 mb-3">Payment Method</h3>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                        {availablePaymentMethods.map((method) => (
                          <button
                            key={method.method}
                            type="button"
                            className={`border rounded-lg p-4 flex items-center justify-center gap-2 ${
                              paymentMethod === method.method 
                                ? 'border-blue-600 bg-blue-50' 
                                : 'border-gray-200 hover:border-gray-300'
                            }`}
                            onClick={() => setPaymentMethod(method.method)}
                          >
                            {method.icon_url ? (
                              <img 
                                src={method.icon_url} 
                                alt={method.display_name || method.method}
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
                            ) : method.method === 'friend_payment' ? (
                              <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                <path d="M17.0595 12.4887L13.0819 8.51099C12.6754 8.10446 12.0289 8.10446 11.6222 8.51099L7.64461 12.4887C7.24695 12.8864 7.24695 13.5138 7.64461 13.9113C8.04228 14.309 8.67988 14.309 9.07755 13.9113L11.6222 11.3667C11.8254 11.1633 12.1541 11.1633 12.3574 11.3667L14.9021 13.9113C15.0997 14.1091 15.3573 14.208 15.6062 14.208C15.8553 14.208 16.1039 14.1091 16.3106 13.9113C16.7084 13.5138 16.7084 12.8864 16.3106 12.4887" fill="#32BCAD"/>
                                <path d="M20.0235 3.96777C16.0082 -0.0487572 9.35046 -0.0487591 5.33509 3.96776C1.31857 7.98429 1.31857 14.6409 5.33509 18.6575L11.6797 24.9999L18.0242 18.6575C22.04 14.6409 22.04 7.98429 20.0235 3.96777ZM16.9139 16.6651L11.6797 21.8994L6.44541 16.6651C3.37007 13.5898 3.37006 8.5259 6.44541 5.4505C8.03755 3.85835 10.1252 3.06743 12.2135 3.06743C14.3019 3.06743 16.3813 3.85835 17.9734 5.4505C19.5563 7.03267 20.3561 9.1192 20.3561 11.2075C20.3561 13.2959 19.5563 15.3825 17.9734 16.9745C17.6205 17.3274 17.2387 17.5975 16.9139 17.9223" fill="#32BCAD"/>
                              </svg>
                            ) : (
                              <div className="h-5 w-5 bg-gray-200 rounded-full"></div>
                            )}
                            <span>{method.display_name || method.method.replace('_', ' ')}</span>
                            {method.test_mode && (
                              <Badge variant="warning" size="sm">Test</Badge>
                            )}
                          </button>
                        ))}
                      </div>
                    </div>
                    
                    {paymentMethod === 'credit_card' && (
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                        <Input
                          label="Card Number"
                          name="cardNumber"
                          value={formData.cardNumber}
                          onChange={handleInputChange}
                          placeholder="1234 5678 9012 3456"
                          required
                        />
                        <Input
                          label="Cardholder Name"
                          name="cardName"
                          value={formData.cardName}
                          onChange={handleInputChange}
                          placeholder="John Doe"
                          required
                        />
                        <Input
                          label="Expiry Date"
                          name="expiryDate"
                          value={formData.expiryDate}
                          onChange={handleInputChange}
                          placeholder="MM/YY"
                          required
                        />
                        <Input
                          label="CVV"
                          name="cvv"
                          value={formData.cvv}
                          onChange={handleInputChange}
                          placeholder="123"
                          required
                        />
                      </div>
                    )}
                    
                    {paymentMethod === 'friend_payment' && (
                      <div className="mt-4">
                        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                          <div className="flex items-start">
                            <AlertCircle className="h-5 w-5 text-yellow-600 mt-0.5 mr-3" />
                            <div>
                              <h4 className="text-yellow-800 font-medium">Friend Payment Information</h4>
                              <p className="text-yellow-700 text-sm mt-1">
                                After placing the order, you'll receive a link that you can share with your friends. They can then contribute to the payment.
                              </p>
                            </div>
                          </div>
                        </div>
                      </div>
                    )}

                    {paymentMethod === 'acacia_pay' && (
                      <div className="mt-4">
                        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                          <div className="flex items-start">
                            <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 mr-3" />
                            <div>
                              <h4 className="text-blue-800 font-medium">Acacia Pay Information</h4>
                              <p className="text-blue-700 text-sm mt-1">
                                You will be redirected to Acacia Pay to complete your payment securely.
                                After payment is completed, you will be returned to this site.
                              </p>
                            </div>
                          </div>
                        </div>
                      </div>
                    )}
                    
                    <div className="mt-4 flex justify-end">
                      <Button 
                        type="button" 
                        onClick={() => handleSectionToggle('review')}
                      >
                        Continue to Review
                      </Button>
                    </div>
                  </div>
                </CardContent>
              )}
            </Card>
            
            <Card className="mb-6">
              <CardHeader
                className="cursor-pointer"
                onClick={() => handleSectionToggle('review')}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center">
                    <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 mr-3">
                      <Clock className="h-5 w-5" />
                    </div>
                    <CardTitle>Order Review</CardTitle>
                  </div>
                  {activeSection === 'review' ? (
                    <ChevronUp className="h-5 w-5 text-gray-500" />
                  ) : (
                    <ChevronDown className="h-5 w-5 text-gray-500" />
                  )}
                </div>
              </CardHeader>
              
              {activeSection === 'review' && (
                <CardContent>
                  <div className="space-y-6">
                    <div>
                      <h3 className="font-medium text-gray-900 mb-3">Order Items</h3>
                      <div className="space-y-3">
                        {items.map((item) => (
                          <div key={item.product.id} className="flex items-center">
                            <div className="h-16 w-16 flex-shrink-0 overflow-hidden rounded-md border border-gray-200">
                              <img
                                src={item.product.images[0]}
                                alt={item.product.name}
                                className="h-full w-full object-cover object-center"
                              />
                            </div>
                            <div className="ml-4 flex-1">
                              <div className="font-medium text-gray-900">{item.product.name}</div>
                              <div className="text-gray-500">Quantity: {item.quantity}</div>
                            </div>
                            <div className="text-right">
                              <div className="font-medium text-gray-900">
                                {formatCurrency(
                                  item.product.discount
                                    ? item.product.price * (1 - item.product.discount / 100) * item.quantity
                                    : item.product.price * item.quantity
                                )}
                              </div>
                              {item.product.discount > 0 && (
                                <div className="text-sm text-gray-500 line-through">
                                  {formatCurrency(item.product.price * item.quantity)}
                                </div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                    
                    <div>
                      <h3 className="font-medium text-gray-900 mb-3">Order Summary</h3>
                      <div className="rounded-lg bg-gray-50 p-4">
                        <div className="space-y-2">
                          <div className="flex justify-between text-gray-500">
                            <span>Subtotal</span>
                            <span>{formatCurrency(subtotal)}</span>
                          </div>
                          <div className="flex justify-between text-gray-500">
                            <span>Shipping</span>
                            <span>{formatCurrency(shippingCost)}</span>
                          </div>
                          <div className="flex justify-between text-gray-500">
                            <span>Tax</span>
                            <span>{formatCurrency(taxAmount)}</span>
                          </div>
                          <div className="border-t border-gray-200 pt-2 flex justify-between font-medium text-gray-900">
                            <span>Total</span>
                            <span>{formatCurrency(total)}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex justify-end">
                      <Button
                        type="submit"
                        disabled={isProcessing}
                        className="w-full md:w-auto"
                      >
                        {isProcessing ? (
                          <span className="flex items-center">
                            <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                            </svg>
                            Processing...
                          </span>
                        ) : (
                          <span className="flex items-center">
                            {paymentMethod === 'acacia_pay' ? 'Proceed to Payment' : 'Place Order'}
                            <ArrowRight className="ml-2 h-4 w-4" />
                          </span>
                        )}
                      </Button>
                    </div>
                  </div>
                </CardContent>
              )}
            </Card>
          </form>
        </div>
        
        <div className="lg:w-1/3">
          <div className="sticky top-4">
            <Card>
              <CardHeader>
                <CardTitle>Order Summary</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div>
                    <div className="text-sm font-medium text-gray-900 mb-2">
                      {items.length} {items.length === 1 ? 'item' : 'items'}
                    </div>
                    <div className="max-h-48 overflow-auto space-y-2">
                      {items.map((item) => (
                        <div key={item.product.id} className="flex items-center text-sm">
                          <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded-md border border-gray-200">
                            <img
                              src={item.product.images[0]}
                              alt={item.product.name}
                              className="h-full w-full object-cover object-center"
                            />
                          </div>
                          <div className="ml-3 flex-1">
                            <div className="font-medium text-gray-900">{item.product.name}</div>
                            <div className="text-gray-500">Qty: {item.quantity}</div>
                          </div>
                          <div className="text-right">
                            <div className="font-medium text-gray-900">
                              {formatCurrency(
                                item.product.discount
                                  ? item.product.price * (1 - item.product.discount / 100) * item.quantity
                                  : item.product.price * item.quantity
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                  
                  <div className="border-t border-gray-200 pt-4 space-y-2">
                    <div className="flex justify-between text-sm text-gray-500">
                      <span>Subtotal</span>
                      <span>{formatCurrency(subtotal)}</span>
                    </div>
                    <div className="flex justify-between text-sm text-gray-500">
                      <span>Shipping</span>
                      <span>{formatCurrency(shippingCost)}</span>
                    </div>
                    <div className="flex justify-between text-sm text-gray-500">
                      <span>Tax</span>
                      <span>{formatCurrency(taxAmount)}</span>
                    </div>
                    <div className="border-t border-gray-200 pt-2 flex justify-between font-medium text-gray-900">
                      <span>Total</span>
                      <span>{formatCurrency(total)}</span>
                    </div>
                  </div>
                  
                  {subtotal < 50 && (
                    <div className="border-t border-gray-200 pt-4">
                      <div className="text-sm text-gray-500">
                        Add {formatCurrency(50 - subtotal)} more to get free shipping!
                      </div>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
      
      {shareModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="max-w-md w-full p-6">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-medium text-gray-900">Share Payment Link</h3>
              <button
                type="button"
                className="text-gray-400 hover:text-gray-500"
                onClick={() => setShareModalOpen(false)}
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="space-y-4">
              <p className="text-sm text-gray-500">
                Share this payment link with your friends. The order will be processed once they complete the payment.
              </p>
              
              <div className="flex items-center space-x-2">
                <input
                  type="text"
                  value={shareLink}
                  readOnly
                  className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <Button
                  type="button"
                  variant="outline"
                  onClick={handleCopyLink}
                  className="flex-shrink-0"
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
              
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div className="flex items-center text-blue-800 font-medium mb-1">
                  <AlertCircle className="h-5 w-5 mr-2" />
                  Important
                </div>
                <p className="text-sm text-blue-700">
                  Keep this link safe! Anyone with this link can complete the payment for this order.
                </p>
              </div>
              
              <div className="flex justify-end space-x-3">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => window.open(shareLink, '_blank')}
                >
                  <ExternalLink className="h-4 w-4 mr-2" />
                  Open Link
                </Button>
                <Button
                  type="button"
                  onClick={() => setShareModalOpen(false)}
                >
                  Done
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
};

export default CheckoutPage;