import React, { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { 
  Heart, Share, ShoppingCart, Plus, Minus, Truck, Clock, RefreshCw, Check, ChevronRight 
} from 'lucide-react';
import { toast } from 'react-hot-toast';
import Button from '../components/ui/Button';
import Badge from '../components/ui/Badge';
import { formatCurrency } from '../lib/utils';
import { useCartStore } from '../store/cart-store';
import ProductCard from '../components/products/ProductCard';
import { getProductById, getProducts } from '../services/product-service';
import { Product } from '../types';
import { mockCategories } from '../data/mockData';

const ProductDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { addItem } = useCartStore();
  
  const [product, setProduct] = useState<Product | null>(null);
  const [quantity, setQuantity] = useState(1);
  const [selectedImage, setSelectedImage] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [relatedProducts, setRelatedProducts] = useState<Product[]>([]);
  const [error, setError] = useState<string | null>(null);

  const fetchProductData = useCallback(async () => {
    if (!id) return;

    setIsLoading(true);
    setError(null);

    try {
      const productData = await getProductById(id);
      
      if (!productData) {
        setError('Product not found');
        return;
      }

      setProduct(productData);

      // Fetch related products from the same category
      const { data: relatedData } = await getProducts({
        category: productData.categoryId,
        limit: 4
      });

      // Filter out the current product
      setRelatedProducts(relatedData.filter(p => p.id !== id));
    } catch (err) {
      console.error('Error fetching product:', err);
      setError('Failed to load product');
    } finally {
      setIsLoading(false);
    }
  }, [id]);
      
  useEffect(() => {
    fetchProductData();
  }, [fetchProductData]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="flex flex-col md:flex-row gap-8">
            <div className="md:w-1/2">
              <div className="bg-gray-200 rounded-lg aspect-square mb-4"></div>
              <div className="flex gap-2">
                {[...Array(4)].map((_, i) => (
                  <div key={i} className="bg-gray-200 rounded-lg aspect-square w-20"></div>
                ))}
              </div>
            </div>
            <div className="md:w-1/2">
              <div className="h-8 bg-gray-200 rounded w-3/4 mb-4"></div>
              <div className="h-6 bg-gray-200 rounded w-1/2 mb-6"></div>
              <div className="h-10 bg-gray-200 rounded w-1/3 mb-6"></div>
              <div className="h-4 bg-gray-200 rounded w-full mb-2"></div>
              <div className="h-4 bg-gray-200 rounded w-full mb-2"></div>
              <div className="h-4 bg-gray-200 rounded w-3/4 mb-6"></div>
              <div className="h-12 bg-gray-200 rounded w-full mb-4"></div>
              <div className="h-10 bg-gray-200 rounded w-full"></div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (error || !product) {
    return (
      <div className="container mx-auto px-4 py-16 text-center">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Product Not Found</h2>
        <p className="text-gray-600 mb-6">The product you're looking for doesn't exist or has been removed.</p>
        <Link to="/products">
          <Button>Back to Products</Button>
        </Link>
      </div>
    );
  }

  const category = mockCategories.find(c => c.id === product.categoryId);
  const isOnSale = product.discount && product.discount > 0;
  const discountedPrice = isOnSale 
    ? product.price - (product.price * product.discount / 100) 
    : product.price;

  const handleQuantityChange = (newQuantity: number) => {
    if (newQuantity >= 1 && newQuantity <= product.inventory) {
      setQuantity(newQuantity);
    }
  };

  const handleAddToCart = () => {
    addItem(product, quantity);
    toast.success(`${quantity} × ${product.name} added to cart`);
  };

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Breadcrumb */}
      <div className="flex items-center text-sm text-gray-500 mb-6">
        <Link to="/" className="hover:text-blue-600">Home</Link>
        <ChevronRight className="h-4 w-4 mx-1" />
        <Link to="/products" className="hover:text-blue-600">Products</Link>
        <ChevronRight className="h-4 w-4 mx-1" />
        <Link to={`/products?category=${category?.id}`} className="hover:text-blue-600">
          {category?.name}
        </Link>
        <ChevronRight className="h-4 w-4 mx-1" />
        <span className="text-gray-900 font-medium">{product.name}</span>
      </div>
      
      <div className="flex flex-col md:flex-row gap-8 mb-12">
        {/* Product Images */}
        <div className="md:w-1/2">
          <div className="rounded-lg overflow-hidden mb-4">
            <img 
              src={product.images[selectedImage]} 
              alt={product.name}
              className="w-full aspect-square object-cover"
            />
          </div>
          
          <div className="flex gap-2">
            {product.images.map((image, index) => (
              <button
                key={index}
                onClick={() => setSelectedImage(index)}
                className={`rounded-md overflow-hidden border-2 ${
                  selectedImage === index ? 'border-blue-600' : 'border-transparent'
                }`}
              >
                <img 
                  src={image} 
                  alt={`${product.name} - view ${index + 1}`}
                  className="w-20 h-20 object-cover"
                />
              </button>
            ))}
          </div>
        </div>
        
        {/* Product Info */}
        <div className="md:w-1/2">
          <div className="mb-6">
            <h1 className="text-3xl font-bold text-gray-900 mb-2">{product.name}</h1>
            
            <div className="mb-4">
              {isOnSale ? (
                <div className="flex items-center">
                  <span className="text-2xl font-bold text-gray-900">
                    {formatCurrency(discountedPrice)}
                  </span>
                  <span className="ml-2 text-gray-500 line-through">
                    {formatCurrency(product.price)}
                  </span>
                  <Badge
                    variant="danger"
                    className="ml-3"
                  >
                    {product.discount}% OFF
                  </Badge>
                </div>
              ) : (
                <span className="text-2xl font-bold text-gray-900">
                  {formatCurrency(product.price)}
                </span>
              )}
            </div>
            
            <p className="text-gray-600 mb-6">
              {product.description}
            </p>
            
            <div className="flex items-center space-x-4 mb-6">
              <div className="border border-gray-300 rounded-md flex items-center">
                <button
                  onClick={() => handleQuantityChange(quantity - 1)}
                  disabled={quantity <= 1}
                  className="p-2 text-gray-500 hover:text-gray-700 disabled:opacity-50"
                >
                  <Minus className="h-4 w-4" />
                </button>
                <span className="px-4 py-2 border-x border-gray-300 min-w-[40px] text-center">
                  {quantity}
                </span>
                <button
                  onClick={() => handleQuantityChange(quantity + 1)}
                  disabled={quantity >= product.inventory}
                  className="p-2 text-gray-500 hover:text-gray-700 disabled:opacity-50"
                >
                  <Plus className="h-4 w-4" />
                </button>
              </div>
              
              <span className="text-sm text-gray-600">
                {product.inventory} items available
              </span>
            </div>
            
            <div className="flex flex-col sm:flex-row gap-3 mb-6">
              <Button
                className="flex-grow"
                leftIcon={<ShoppingCart className="h-5 w-5" />}
                onClick={handleAddToCart}
              >
                Add to Cart
              </Button>
              <Button
                variant="outline"
                className="flex-grow"
                leftIcon={<Heart className="h-5 w-5" />}
              >
                Add to Wishlist
              </Button>
            </div>
          </div>
          
          <div className="border-t border-gray-200 pt-6 space-y-4">
            <div className="flex items-start">
              <Truck className="h-5 w-5 text-gray-500 mt-0.5 mr-3" />
              <div>
                <h4 className="font-medium text-gray-900">Free Shipping</h4>
                <p className="text-sm text-gray-600">Free standard shipping on orders over $50</p>
              </div>
            </div>
            
            <div className="flex items-start">
              <Clock className="h-5 w-5 text-gray-500 mt-0.5 mr-3" />
              <div>
                <h4 className="font-medium text-gray-900">Fast Delivery</h4>
                <p className="text-sm text-gray-600">Get your order in 2-5 business days</p>
              </div>
            </div>
            
            <div className="flex items-start">
              <RefreshCw className="h-5 w-5 text-gray-500 mt-0.5 mr-3" />
              <div>
                <h4 className="font-medium text-gray-900">Easy Returns</h4>
                <p className="text-sm text-gray-600">30 day money back guarantee</p>
              </div>
            </div>
            
            <div className="flex items-start">
              <Check className="h-5 w-5 text-gray-500 mt-0.5 mr-3" />
              <div>
                <h4 className="font-medium text-gray-900">Secure Checkout</h4>
                <p className="text-sm text-gray-600">SSL / Secure Payment Processing</p>
              </div>
            </div>
          </div>
          
          <div className="border-t border-gray-200 pt-6 mt-6">
            <Button
              variant="ghost"
              leftIcon={<Share className="h-5 w-5" />}
              className="text-gray-600"
            >
              Share this product
            </Button>
          </div>
        </div>
      </div>
      
      {/* Related Products */}
      {relatedProducts.length > 0 && (
        <div className="border-t border-gray-200 pt-12">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold text-gray-900">Related Products</h2>
            <Link 
              to={`/products?category=${product.categoryId}`}
              className="text-blue-600 hover:text-blue-800 flex items-center"
            >
              View all <ChevronRight className="h-5 w-5 ml-1" />
            </Link>
          </div>
          
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {relatedProducts.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default ProductDetailPage;