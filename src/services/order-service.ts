import { supabase } from '../lib/supabase';
import { Order, OrderItem, CartItem, SharedOrder, PaymentMethod } from '../types';
import { generateOrderNumber, generateShareId } from '../lib/utils';

// Get shared order by share ID
export const getSharedOrderByShareId = async (shareId: string): Promise<SharedOrder | null> => {
  try {
    const { data, error } = await supabase
      .rpc('get_shared_order_details', {
        p_share_id: shareId
      });
    
    if (error) throw error;
    if (!data || data.error) return null;
    
    return {
      shareId: data.share_id,
      orderId: data.order.id,
      items: data.order.items,
      total: data.order.total,
      status: data.order.status,
      paymentStatus: data.order.payment_status,
      shippingAddress: data.order.shipping_address,
      expiresAt: data.expires_at,
      createdAt: data.created_at
    };
  } catch (error) {
    console.error('Error fetching shared order:', error);
    return null;
  }
};

// Process payment for shared order
export const processSharedOrderPayment = async (
  shareId: string,
  paymentMethod: string
): Promise<{ success: boolean; orderId?: string; orderNumber?: string; error?: string; paymentUrl?: string }> => {
  try {
    const { data, error } = await supabase
      .rpc('process_friend_payment', {
        p_share_id: shareId,
        p_payment_method: paymentMethod
      });
    
    if (error) {
      console.error('Error processing shared order payment:', error);
      throw error;
    }
    
    if (!data || !data.success) {
      return { 
        success: false, 
        error: data?.error || 'Failed to process payment. No response from server.' 
      };
    }
    
    return data;
  } catch (error) {
    console.error('Error processing shared order payment:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to process payment'
    };
  }
};

// Get orders for current user
export const getUserOrders = async (): Promise<Order[]> => {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      order_items:order_items(
        *,
        product:products(*)
      )
    `)
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(order => ({
    id: order.id,
    orderNumber: order.order_number,
    userId: order.user_id,
    items: order.order_items.map((item: any) => ({
      id: item.id,
      orderId: item.order_id,
      productId: item.product_id,
      product: {
        id: item.product.id,
        name: item.product.name,
        description: item.product.description || '',
        price: item.product.price,
        images: item.product.images,
        categoryId: item.product.category_id || '',
        inventory: item.product.inventory,
        discount: item.product.discount || undefined,
        featured: item.product.featured || false,
        createdAt: item.product.created_at,
        updatedAt: item.product.updated_at
      },
      quantity: item.quantity,
      price: item.price
    })),
    status: order.status,
    shippingAddressId: order.shipping_address_id || '',
    paymentMethod: order.payment_method,
    paymentStatus: order.payment_status,
    subtotal: order.subtotal,
    tax: order.tax,
    shipping: order.shipping,
    total: order.total,
    trackingNumber: order.tracking_number,
    createdAt: order.created_at,
    updatedAt: order.updated_at,
  }));
};

// Get order by ID
export const getOrderById = async (id: string): Promise<Order | null> => {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      order_items:order_items(
        *,
        product:products(*)
      )
    `)
    .eq('id', id)
    .single();
  
  if (error || !data) return null;
  
  return {
    id: data.id,
    orderNumber: data.order_number,
    userId: data.user_id,
    items: data.order_items.map((item: any) => ({
      id: item.id,
      orderId: item.order_id,
      productId: item.product_id,
      product: {
        id: item.product.id,
        name: item.product.name,
        description: item.product.description || '',
        price: item.product.price,
        images: item.product.images,
        categoryId: item.product.category_id || '',
        inventory: item.product.inventory,
        discount: item.product.discount || undefined,
        featured: item.product.featured || false,
        createdAt: item.product.created_at,
        updatedAt: item.product.updated_at
      },
      quantity: item.quantity,
      price: item.price
    })),
    status: data.status,
    shippingAddressId: data.shipping_address_id || '',
    paymentMethod: data.payment_method,
    paymentStatus: data.payment_status,
    subtotal: data.subtotal,
    tax: data.tax,
    shipping: data.shipping,
    total: data.total,
    trackingNumber: data.tracking_number,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
  };
};

// Create order
export const createOrder = async (
  userId: string,
  items: CartItem[],
  shippingAddressId: string,
  paymentMethod: string,
  subtotal: number,
  tax: number,
  shipping: number,
  total: number
): Promise<Order> => {
  const orderNumber = generateOrderNumber();
  
  // Start a transaction
  const { data, error } = await supabase
    .from('orders')
    .insert({
      order_number: orderNumber,
      user_id: userId,
      shipping_address_id: shippingAddressId,
      payment_method: paymentMethod,
      subtotal,
      tax,
      shipping,
      total
    })
    .select()
    .single();
  
  if (error) throw error;
  
  const orderId = data.id;
  
  // Insert order items
  const orderItems = items.map(item => {
    const effectivePrice = item.product.discount 
      ? item.product.price * (1 - item.product.discount / 100) 
      : item.product.price;
      
    return {
      order_id: orderId,
      product_id: item.product.id,
      quantity: item.quantity,
      price: effectivePrice
    };
  });
  
  const { error: itemsError } = await supabase
    .from('order_items')
    .insert(orderItems);
  
  if (itemsError) throw itemsError;
  
  // Update product inventory
  for (const item of items) {
    const { error: inventoryError } = await supabase
      .from('products')
      .update({
        inventory: item.product.inventory - item.quantity
      })
      .eq('id', item.product.id);
    
    if (inventoryError) throw inventoryError;
  }
  
  // Return the created order
  return await getOrderById(orderId) as Order;
};

// Generate shared order link
export const createSharedOrder = async (orderId: string, expiryHours: number = 24): Promise<string> => {
  const shareId = generateShareId();
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + expiryHours);
  
  const { error } = await supabase
    .from('shared_orders')
    .insert({
      share_id: shareId,
      order_id: orderId,
      expires_at: expiresAt.toISOString()
    });
  
  if (error) throw error;
  
  return shareId;
};

// Update order status
export const updateOrderStatus = async (orderId: string, status: Order['status']): Promise<void> => {
  const { error } = await supabase
    .from('orders')
    .update({ status })
    .eq('id', orderId);
  
  if (error) throw error;
};

// Update payment status
export const updatePaymentStatus = async (orderId: string, status: Order['paymentStatus']): Promise<void> => {
  const { error } = await supabase
    .from('orders')
    .update({ payment_status: status })
    .eq('id', orderId);
  
  if (error) throw error;
};

// For admin - Get all orders
export const getAllOrders = async (): Promise<Order[]> => {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      order_items:order_items(
        *,
        product:products(*)
      )
    `)
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(order => ({
    id: order.id,
    orderNumber: order.order_number,
    userId: order.user_id,
    items: order.order_items.map((item: any) => ({
      id: item.id,
      orderId: item.order_id,
      productId: item.product_id,
      product: {
        id: item.product.id,
        name: item.product.name,
        description: item.product.description || '',
        price: item.product.price,
        images: item.product.images,
        categoryId: item.product.category_id || '',
        inventory: item.product.inventory,
        discount: item.product.discount || undefined,
        featured: item.product.featured || false,
        createdAt: item.product.created_at,
        updatedAt: item.product.updated_at
      },
      quantity: item.quantity,
      price: item.price
    })),
    status: order.status,
    shippingAddressId: order.shipping_address_id || '',
    paymentMethod: order.payment_method,
    paymentStatus: order.payment_status,
    subtotal: order.subtotal,
    tax: order.tax,
    shipping: order.shipping,
    total: order.total,
    trackingNumber: order.tracking_number,
    createdAt: order.created_at,
    updatedAt: order.updated_at,
  }));
};

// For agent - Get agent orders
export const getAgentOrders = async (agentId: string): Promise<Order[]> => {
  const { data, error } = await supabase
    .from('commissions')
    .select(`
      order_id,
      orders:orders(
        *,
        order_items:order_items(
          *,
          product:products(*)
        )
      )
    `)
    .eq('agent_id', agentId);
  
  if (error) throw error;
  
  return (data || []).map((commission: any) => {
    const order = commission.orders;
    return {
      id: order.id,
      orderNumber: order.order_number,
      userId: order.user_id,
      items: order.order_items.map((item: any) => ({
        id: item.id,
        orderId: item.order_id,
        productId: item.product_id,
        product: {
          id: item.product.id,
          name: item.product.name,
          description: item.product.description || '',
          price: item.product.price,
          images: item.product.images,
          categoryId: item.product.category_id || '',
          inventory: item.product.inventory,
          discount: item.product.discount || undefined,
          featured: item.product.featured || false,
          createdAt: item.product.created_at,
          updatedAt: item.product.updated_at
        },
        quantity: item.quantity,
        price: item.price
      })),
      status: order.status,
      shippingAddressId: order.shipping_address_id || '',
      paymentMethod: order.payment_method,
      paymentStatus: order.payment_status,
      subtotal: order.subtotal,
      tax: order.tax,
      shipping: order.shipping,
      total: order.total,
      trackingNumber: order.tracking_number,
      createdAt: order.created_at,
      updatedAt: order.updated_at,
    };
  });
};