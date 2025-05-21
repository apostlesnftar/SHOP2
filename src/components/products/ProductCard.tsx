import React from 'react';
import { Link } from 'react-router-dom';
import { Heart, ShoppingCart } from 'lucide-react';
import { Product } from '../../types';
import Button from '../ui/Button';
import Badge from '../ui/Badge';
import { formatCurrency } from '../../lib/utils';
import { useCartStore } from '../../store/cart-store';
import { toast } from 'react-hot-toast';

interface ProductCardProps {
  product: Product;
  layout?: 'grid' | 'list';
}

const ProductCard: React.FC<ProductCardProps> = ({ product, layout = 'grid' }) => {
  const { addItem } = useCartStore();
  
  const handleAddToCart = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    addItem(product, 1);
    toast.success(`${product.name} added to cart`);
  };
  
  const isOnSale = product.discount && product.discount > 0;
  const discountedPrice = isOnSale 
    ? product.price - (product.price * product.discount / 100) 
    : product.price;
  
  if (layout === 'list') {
    return (
      <Link
        to={`/products/${product.id}`}
        className="block bg-white rounded-lg shadow-sm overflow-hidden hover:shadow-md transition-shadow"
      >
        <div className="flex flex-col md:flex-row">
          <div className="md:w-1/3 relative">
            <img
              src={product.images[0]}
              alt={product.name}
              className="w-full h-48 md:h-full object-cover"
            />
            {isOnSale && (
              <Badge
                variant="danger"
                className="absolute top-2 left-2"
              >
                {product.discount}% OFF
              </Badge>
            )}
          </div>
          
          <div className="p-4 md:p-6 flex-1">
            <h3 className="text-lg font-semibold text-gray-900 mb-1">
              {product.name}
            </h3>
            
            <div className="mb-2">
              {isOnSale ? (
                <div className="flex items-center">
                  <span className="font-bold text-gray-900">
                    {formatCurrency(discountedPrice)}
                  </span>
                  <span className="ml-2 text-sm text-gray-500 line-through">
                    {formatCurrency(product.price)}
                  </span>
                </div>
              ) : (
                <span className="font-bold text-gray-900">
                  {formatCurrency(product.price)}
                </span>
              )}
            </div>
            
            <p className="text-gray-600 mb-4 line-clamp-2">
              {product.description}
            </p>
            
            <div className="flex items-center space-x-2">
              <Button
                onClick={handleAddToCart}
                leftIcon={<ShoppingCart className="h-4 w-4" />}
              >
                Add to Cart
              </Button>
              <Button
                variant="outline"
                className="px-3"
                aria-label="Add to wishlist"
              >
                <Heart className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      </Link>
    );
  }
  
  return (
    <Link
      to={`/products/${product.id}`}
      className="group block bg-white rounded-lg shadow-sm overflow-hidden hover:shadow-md transition-shadow"
    >
      <div className="relative aspect-square overflow-hidden">
        <img
          src={product.images[0]}
          alt={product.name}
          className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
        />
        {isOnSale && (
          <Badge
            variant="danger"
            className="absolute top-2 left-2"
          >
            {product.discount}% OFF
          </Badge>
        )}
        <div className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-opacity"></div>
      </div>
      
      <div className="p-4">
        <h3 className="font-medium text-gray-900 mb-1 group-hover:text-blue-600 transition-colors">
          {product.name}
        </h3>
        
        <div className="mb-3">
          {isOnSale ? (
            <div className="flex items-center">
              <span className="font-bold text-gray-900">
                {formatCurrency(discountedPrice)}
              </span>
              <span className="ml-2 text-sm text-gray-500 line-through">
                {formatCurrency(product.price)}
              </span>
            </div>
          ) : (
            <span className="font-bold text-gray-900">
              {formatCurrency(product.price)}
            </span>
          )}
        </div>
        
        <div className="flex space-x-2">
          <Button
            size="sm"
            onClick={handleAddToCart}
            className="flex-grow"
            leftIcon={<ShoppingCart className="h-4 w-4" />}
          >
            Add
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="p-0 w-9 flex justify-center"
            aria-label="Add to wishlist"
          >
            <Heart className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </Link>
  );
};

export default ProductCard;