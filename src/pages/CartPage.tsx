import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Trash2, ArrowRight, Plus, Minus, ShoppingCart } from 'lucide-react';
import Button from '../components/ui/Button';
import { Card, CardContent, CardFooter } from '../components/ui/Card';
import { useCartStore } from '../store/cart-store';
import { formatCurrency } from '../lib/utils';

const CartPage: React.FC = () => {
  const { items, removeItem, updateQuantity, clearCart, getSubtotal } = useCartStore();
  const navigate = useNavigate();
  
  const [isLoading, setIsLoading] = useState(false);
  
  const subtotal = getSubtotal();
  const shippingCost = subtotal > 50 ? 0 : 10;
  const taxRate = 0.08; // 8%
  const taxAmount = subtotal * taxRate;
  const total = subtotal + shippingCost + taxAmount;
  
  const handleQuantityChange = (productId: string, quantity: number) => {
    const item = items.find(item => item.productId === productId);
    if (item && quantity >= 1 && quantity <= item.product.inventory) {
      updateQuantity(productId, quantity);
    }
  };
  
  const handleRemoveItem = (productId: string) => {
    removeItem(productId);
  };
  
  const handleCheckout = () => {
    setIsLoading(true);
    // Simulate a brief loading state before navigating
    setTimeout(() => {
      setIsLoading(false);
      navigate('/checkout');
    }, 500);
  };
  
  if (items.length === 0) {
    return (
      <div className="container mx-auto px-4 py-12 text-center">
        <div className="flex flex-col items-center justify-center max-w-md mx-auto">
          <ShoppingCart className="h-24 w-24 text-gray-300 mb-6" />
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Your cart is empty</h1>
          <p className="text-gray-600 mb-8">
            Looks like you haven't added anything to your cart yet.
          </p>
          <Link to="/products">
            <Button size="lg">Browse Products</Button>
          </Link>
        </div>
      </div>
    );
  }
  
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold text-gray-900 mb-8">Shopping Cart</h1>
      
      <div className="flex flex-col lg:flex-row gap-8">
        {/* Cart Items */}
        <div className="lg:w-2/3">
          <Card>
            <div className="hidden sm:flex bg-gray-50 px-6 py-3 border-b border-gray-200">
              <div className="w-1/2">Product</div>
              <div className="w-1/4 text-center">Quantity</div>
              <div className="w-1/4 text-right">Price</div>
            </div>
            
            {items.map((item) => {
              const effectivePrice = item.product.discount 
                ? item.product.price * (1 - item.product.discount / 100) 
                : item.product.price;
              
              return (
                <div 
                  key={item.productId} 
                  className="px-6 py-4 border-b border-gray-200 last:border-b-0"
                >
                  <div className="flex flex-col sm:flex-row sm:items-center">
                    {/* Product Info */}
                    <div className="sm:w-1/2 flex mb-4 sm:mb-0">
                      <Link 
                        to={`/products/${item.productId}`}
                        className="w-20 h-20 bg-gray-100 rounded-md overflow-hidden flex-shrink-0"
                      >
                        <img 
                          src={item.product.images[0]} 
                          alt={item.product.name} 
                          className="w-full h-full object-cover"
                        />
                      </Link>
                      <div className="ml-4">
                        <Link 
                          to={`/products/${item.productId}`} 
                          className="font-medium text-gray-900 hover:text-blue-600"
                        >
                          {item.product.name}
                        </Link>
                        {item.product.discount ? (
                          <div className="flex items-center mt-1">
                            <span className="font-semibold">
                              {formatCurrency(effectivePrice)}
                            </span>
                            <span className="ml-2 text-sm text-gray-500 line-through">
                              {formatCurrency(item.product.price)}
                            </span>
                          </div>
                        ) : (
                          <div className="mt-1 font-semibold">
                            {formatCurrency(item.product.price)}
                          </div>
                        )}
                      </div>
                    </div>
                    
                    {/* Quantity */}
                    <div className="sm:w-1/4 flex justify-start sm:justify-center mb-4 sm:mb-0">
                      <div className="border border-gray-300 rounded-md flex items-center">
                        <button
                          onClick={() => handleQuantityChange(item.productId, item.quantity - 1)}
                          disabled={item.quantity <= 1}
                          className="p-1 text-gray-500 hover:text-gray-700 disabled:opacity-50"
                        >
                          <Minus className="h-4 w-4" />
                        </button>
                        <span className="px-3 py-1 border-x border-gray-300 min-w-[36px] text-center">
                          {item.quantity}
                        </span>
                        <button
                          onClick={() => handleQuantityChange(item.productId, item.quantity + 1)}
                          disabled={item.quantity >= item.product.inventory}
                          className="p-1 text-gray-500 hover:text-gray-700 disabled:opacity-50"
                        >
                          <Plus className="h-4 w-4" />
                        </button>
                      </div>
                    </div>
                    
                    {/* Price */}
                    <div className="sm:w-1/4 flex justify-between sm:justify-end items-center">
                      <span className="sm:hidden">Total:</span>
                      <div className="font-bold text-gray-900">
                        {formatCurrency(effectivePrice * item.quantity)}
                      </div>
                      <button
                        onClick={() => handleRemoveItem(item.productId)}
                        className="ml-4 text-gray-400 hover:text-red-600"
                      >
                        <Trash2 className="h-5 w-5" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
            
            <CardFooter className="flex justify-between border-t border-gray-200">
              <Button
                variant="ghost"
                className="text-gray-500"
                onClick={() => clearCart()}
              >
                Clear Cart
              </Button>
              <Link to="/products">
                <Button variant="outline">Continue Shopping</Button>
              </Link>
            </CardFooter>
          </Card>
        </div>
        
        {/* Order Summary */}
        <div className="lg:w-1/3">
          <Card>
            <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">Order Summary</h2>
            </div>
            
            <CardContent className="p-6 space-y-4">
              <div className="flex justify-between">
                <span className="text-gray-600">Subtotal</span>
                <span className="font-medium">{formatCurrency(subtotal)}</span>
              </div>
              
              <div className="flex justify-between">
                <span className="text-gray-600">Shipping</span>
                {shippingCost > 0 ? (
                  <span className="font-medium">{formatCurrency(shippingCost)}</span>
                ) : (
                  <span className="text-green-600 font-medium">Free</span>
                )}
              </div>
              
              <div className="flex justify-between">
                <span className="text-gray-600">Tax (8%)</span>
                <span className="font-medium">{formatCurrency(taxAmount)}</span>
              </div>
              
              <div className="border-t border-gray-200 pt-4 flex justify-between items-center">
                <span className="text-lg font-semibold text-gray-900">Total</span>
                <span className="text-xl font-bold text-gray-900">{formatCurrency(total)}</span>
              </div>
              
              {shippingCost > 0 && (
                <p className="text-sm text-green-600">
                  Add ${formatCurrency(50 - subtotal)} more to qualify for free shipping!
                </p>
              )}
            </CardContent>
            
            <CardFooter className="p-6 pt-0">
              <Button
                className="w-full"
                size="lg"
                rightIcon={<ArrowRight className="h-5 w-5" />}
                onClick={handleCheckout}
                isLoading={isLoading}
              >
                Proceed to Checkout
              </Button>
            </CardFooter>
          </Card>
          
          <div className="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h3 className="font-medium text-blue-800 mb-1">Group Payment Available</h3>
            <p className="text-sm text-blue-700">
              Invite friends to split the payment for this order during checkout!
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CartPage;