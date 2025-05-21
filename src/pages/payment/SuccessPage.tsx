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
      
      // Adjust the success URL to include the share ID
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

    // For other payment methods, handle the payment
    const { data, error } = await supabase.rpc('process_friend_payment', {
      p_share_id: shareId,
      p_payment_method: selectedPaymentMethod
    });

    if (error) throw error;

    if (!data || !data.success) {
      console.error('Payment processing failed:', data?.error || 'Unknown error', data);
      throw new Error(data?.error || 'Payment processing failed');
    }

    toast.success('Payment processed successfully!');
    
    // Redirect to the success page with share ID as a query parameter
    navigate(`/payment/success?share=${shareId}`);
  } catch (err) {
    console.error('Payment error:', err);
    toast.error(err instanceof Error ? err.message : 'Failed to process payment');
  } finally {
    setIsProcessing(false);
  }
};
