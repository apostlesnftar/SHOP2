import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, ShoppingBag, Users, Shield, TrendingUp } from 'lucide-react';
import Button from '../components/ui/Button';
import { Card, CardContent } from '../components/ui/Card';
import { getProducts, getAllCategories } from '../services/product-service';
import { formatCurrency } from '../lib/utils';
import { Product, Category } from '../types';
import { testConnection } from '../lib/supabase';

const HomePage: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [featuredProducts, setFeaturedProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        // Test Supabase connection first
        await testConnection();

        // Fetch categories
        const categoriesData = await getAllCategories();
        setCategories(categoriesData);

        // Fetch featured products
        const { data: productsData } = await getProducts({
          featured: true,
          limit: 8
        });
        
        if (!productsData) {
          throw new Error('No products data received');
        }
        
        setFeaturedProducts(productsData);
        setError(null);
      } catch (error) {
        console.error('Error fetching data:', error);
        setError(error instanceof Error ? error.message : 'Failed to fetch data');
        // Set empty arrays to prevent undefined errors
        setCategories([]);
        setFeaturedProducts([]);
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  // Show error message if there's an error
  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-lg shadow-lg p-6 max-w-md w-full">
          <h2 className="text-2xl font-bold text-red-600 mb-4">Connection Error</h2>
          <p className="text-gray-600 mb-4">{error}</p>
          <p className="text-sm text-gray-500 mb-4">
            Please check your internet connection and ensure Supabase is properly configured.
          </p>
          <Button
            onClick={() => window.location.reload()}
            className="w-full"
          >
            Retry Connection
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* Hero Section */}
      <section className="bg-gradient-to-r from-blue-600 to-blue-800 text-white">
        <div className="container mx-auto px-4 py-20 md:py-24 flex flex-col items-center text-center">
          <h1 className="text-4xl md:text-5xl font-bold mb-6 leading-tight max-w-3xl">
            Your Premier Multi-Functional E-Commerce Platform
          </h1>
          <p className="text-lg md:text-xl mb-8 max-w-2xl opacity-90">
            Shop, sell, and earn with our comprehensive platform. Everything you need in one place.
          </p>
          <div className="flex flex-col sm:flex-row gap-4">
            <Button
              size="lg"
              className="bg-white text-blue-700 hover:bg-gray-100"
              onClick={() => window.location.href = '/products'}
            >
              Start Shopping
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="border-white text-white hover:bg-white/10"
              onClick={() => window.location.href = '/become-agent'}
            >
              Become an Agent
            </Button>
          </div>
        </div>
      </section>
      
      {/* Featured Categories */}
      <section className="py-16 bg-white">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4">Browse Categories</h2>
            <p className="text-gray-600 max-w-2xl mx-auto">
              Discover our wide range of product categories for all your needs
            </p>
          </div>
          
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            {categories.map((category) => (
              <Link 
                key={category.id} 
                to={`/products?category=${category.id}`}
                className="group"
              >
                <div className="rounded-lg overflow-hidden bg-gray-100 aspect-square relative transition-all duration-300 transform group-hover:shadow-lg">
                  <img 
                    src={category.imageUrl} 
                    alt={category.name}
                    className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end">
                    <div className="p-4 w-full">
                      <h3 className="text-white font-semibold text-lg">{category.name}</h3>
                      <div className="flex items-center text-white/80 mt-1 text-sm">
                        <span className="group-hover:mr-2 transition-all duration-300">Shop now</span>
                        <ArrowRight className="h-4 w-0 group-hover:w-4 transition-all duration-300 overflow-hidden" />
                      </div>
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>
      
      {/* Featured Products */}
      <section className="py-16 bg-gray-50">
        <div className="container mx-auto px-4">
          <div className="flex justify-between items-center mb-12">
            <div>
              <h2 className="text-3xl font-bold mb-2">Featured Products</h2>
              <p className="text-gray-600">Handpicked products for you</p>
            </div>
            <Link 
              to="/products" 
              className="flex items-center text-blue-600 font-medium hover:text-blue-800 transition-colors"
            >
              View all <ArrowRight className="ml-2 h-5 w-5" />
            </Link>
          </div>
          
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {isLoading ? (
              // Loading skeleton
              Array.from({ length: 4 }).map((_, index) => (
                <div key={index} className="animate-pulse">
                  <div className="bg-gray-200 aspect-square rounded-lg mb-4"></div>
                  <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                  <div className="h-4 bg-gray-200 rounded w-1/2"></div>
                </div>
              ))
            ) : featuredProducts.map((product) => (
              <Card 
                key={product.id} 
                className="overflow-hidden group"
                hoverable
              >
                <div className="aspect-square overflow-hidden relative">
                  <img 
                    src={product.images[0]} 
                    alt={product.name}
                    className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                  />
                  {product.discount && (
                    <div className="absolute top-2 left-2 bg-red-500 text-white text-xs font-bold px-2 py-1 rounded">
                      {product.discount}% OFF
                    </div>
                  )}
                </div>
                <CardContent className="p-4">
                  <h3 className="font-medium text-gray-900 mb-1 group-hover:text-blue-600 transition-colors">
                    {product.name}
                  </h3>
                  <div className="flex items-center justify-between">
                    <div>
                      {product.discount ? (
                        <div className="flex items-center">
                          <span className="font-bold text-gray-900">
                            {formatCurrency(product.price - (product.price * product.discount / 100))}
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
                    <Link 
                      to={`/products/${product.id}`}
                      className="text-sm text-blue-600 font-medium hover:text-blue-800 transition-colors"
                    >
                      View
                    </Link>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>
      
      {/* Features Section */}
      <section className="py-16 bg-white">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4">Why Choose Us</h2>
            <p className="text-gray-600 max-w-2xl mx-auto">
              Discover the benefits of our comprehensive e-commerce ecosystem
            </p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-blue-100 text-blue-600 mb-4">
                <ShoppingBag className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">Wide Selection</h3>
              <p className="text-gray-600">
                Thousands of products across multiple categories to meet all your needs
              </p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
                <Users className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">Multi-level Marketing</h3>
              <p className="text-gray-600">
                Become an agent and earn commissions by referring customers and other agents
              </p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-amber-100 text-amber-600 mb-4">
                <Shield className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">Secure Payments</h3>
              <p className="text-gray-600">
                Multiple payment options with secure processing and friend payment sharing
              </p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-purple-100 text-purple-600 mb-4">
                <TrendingUp className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">Business Growth</h3>
              <p className="text-gray-600">
                Powerful tools and insights to help agents and vendors grow their business
              </p>
            </div>
          </div>
        </div>
      </section>
      
      {/* CTA Section */}
      <section className="py-16 bg-gray-900 text-white">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold mb-6">Ready to Join Our Platform?</h2>
          <p className="text-gray-300 max-w-2xl mx-auto mb-8">
            Whether you're a shopper or want to become an agent, we're ready to help you succeed
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-4">
            <Button
              size="lg"
              onClick={() => window.location.href = '/register'}
            >
              Create an Account
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="border-white text-white hover:bg-white/10"
              onClick={() => window.location.href = '/learn-more'}
            >
              Learn More
            </Button>
          </div>
        </div>
      </section>
    </div>
  );
};

export default HomePage;