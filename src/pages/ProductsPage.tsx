import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { Search, Filter, X, ChevronDown, Grid, List } from 'lucide-react';
import Button from '../components/ui/Button';
import Input from '../components/ui/Input';
import Select from '../components/ui/Select';
import { Card } from '../components/ui/Card';
import ProductCard from '../components/products/ProductCard';
import { getProducts, getAllCategories } from '../services/product-service';
import { Product } from '../types';

const ProductsPage: React.FC = () => {
  const location = useLocation();
  const queryParams = new URLSearchParams(location.search);
  const categoryParam = queryParams.get('category');
  const searchParam = queryParams.get('q');

  const [products, setProducts] = useState<Product[]>([]);
  const [totalProducts, setTotalProducts] = useState(0);
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const [categories, setCategories] = useState<any[]>([]);
  
  // Filter states
  const [searchQuery, setSearchQuery] = useState(searchParam || '');
  const [selectedCategory, setSelectedCategory] = useState(categoryParam || 'all');
  const [priceRange, setPriceRange] = useState({ min: 0, max: 1000 });
  const [sortBy, setSortBy] = useState('newest');
  const [onlyDiscounted, setOnlyDiscounted] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(12);
  
  useEffect(() => {
    const fetchProducts = async () => {
      setIsLoading(true);
      
      try {
        // Fetch categories if not loaded
        if (categories.length === 0) {
          const categoriesData = await getAllCategories();
          setCategories(categoriesData);
        }
        
        // Fetch products with filters
        const { data, count } = await getProducts({
          page: currentPage,
          limit: itemsPerPage,
          category: selectedCategory !== 'all' ? selectedCategory : undefined,
          search: searchQuery || undefined,
          minPrice: priceRange.min,
          maxPrice: priceRange.max,
          onlyDiscounted,
          sortBy
        });
        
        setProducts(data);
        setTotalProducts(count);
      } catch (error) {
        console.error('Error fetching products:', error);
        // Handle error (show toast, etc.)
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchProducts();
  }, [currentPage, searchQuery, selectedCategory, priceRange, sortBy, onlyDiscounted, itemsPerPage]);
  
  const resetFilters = () => {
    setSearchQuery('');
    setSelectedCategory('all');
    setPriceRange({ min: 0, max: 1000 });
    setSortBy('newest');
    setOnlyDiscounted(false);
    setCurrentPage(1);
  };
  
  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setCurrentPage(1); // Reset to first page when searching
  };
  
  // Generate category options for the select input
  const categoryOptions = [
    { value: 'all', label: 'All Categories' },
    ...categories.map(category => ({
      value: category.id,
      label: category.name
    }))
  ];
  
  // Generate sort options for the select input
  const sortOptions = [
    { value: 'newest', label: 'Newest' },
    { value: 'price-low', label: 'Price: Low to High' },
    { value: 'price-high', label: 'Price: High to Low' },
    { value: 'popular', label: 'Popularity' },
  ];
  
  return (
    <div className="container mx-auto px-4 py-8">
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Products</h1>
        <p className="text-gray-600 mt-1">
          Browse through our collection of quality products
        </p>
      </div>
      
      {/* Search and Filter Bar */}
      <div className="mb-8">
        <div className="flex flex-col md:flex-row gap-4">
          <form onSubmit={handleSearch} className="flex-grow">
            <Input
              type="text"
              placeholder="Search products..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              leftIcon={<Search className="h-5 w-5" />}
              className="w-full"
            />
          </form>
          
          <div className="flex gap-2">
            <Button
              variant="outline"
              className="md:hidden"
              onClick={() => setIsFilterOpen(!isFilterOpen)}
              leftIcon={isFilterOpen ? <X className="h-4 w-4" /> : <Filter className="h-4 w-4" />}
            >
              {isFilterOpen ? 'Close' : 'Filters'}
            </Button>
            
            <Select
              options={sortOptions}
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="min-w-[180px]"
            />
            
            <div className="hidden md:flex gap-2">
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 rounded-md ${viewMode === 'grid' ? 'bg-gray-200' : 'bg-white'}`}
                aria-label="Grid view"
              >
                <Grid className="h-5 w-5" />
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`p-2 rounded-md ${viewMode === 'list' ? 'bg-gray-200' : 'bg-white'}`}
                aria-label="List view"
              >
                <List className="h-5 w-5" />
              </button>
            </div>
          </div>
        </div>
      </div>
      
      <div className="flex flex-col md:flex-row gap-8">
        {/* Filter Sidebar - Desktop */}
        <div className="hidden md:block w-64 flex-shrink-0">
          <Card className="sticky top-24">
            <div className="p-4 border-b border-gray-200">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-gray-900">Filters</h3>
                <button
                  onClick={resetFilters}
                  className="text-sm text-blue-600 hover:text-blue-800"
                >
                  Reset
                </button>
              </div>
            </div>
            
            <div className="p-4 border-b border-gray-200">
              <h4 className="font-medium text-gray-900 mb-3">Category</h4>
              <Select
                options={categoryOptions}
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
              />
            </div>
            
            <div className="p-4 border-b border-gray-200">
              <h4 className="font-medium text-gray-900 mb-3">Price Range</h4>
              <div className="flex items-center gap-2">
                <Input
                  type="number"
                  value={priceRange.min}
                  onChange={(e) => setPriceRange({ ...priceRange, min: Number(e.target.value) })}
                  placeholder="Min"
                  min={0}
                />
                <span className="text-gray-400">-</span>
                <Input
                  type="number"
                  value={priceRange.max}
                  onChange={(e) => setPriceRange({ ...priceRange, max: Number(e.target.value) })}
                  placeholder="Max"
                  min={0}
                />
              </div>
            </div>
            
            <div className="p-4">
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={onlyDiscounted}
                  onChange={(e) => setOnlyDiscounted(e.target.checked)}
                  className="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
                />
                <span className="ml-2 text-gray-700">On Sale</span>
              </label>
            </div>
          </Card>
        </div>
        
        {/* Mobile Filters - Only visible when toggled */}
        {isFilterOpen && (
          <div className="md:hidden bg-white rounded-lg shadow-md mb-4 p-4">
            <div className="mb-4">
              <h3 className="font-semibold text-gray-900 mb-2">Filters</h3>
              <div className="mb-3">
                <h4 className="font-medium text-gray-900 mb-1">Category</h4>
                <Select
                  options={categoryOptions}
                  value={selectedCategory}
                  onChange={(e) => setSelectedCategory(e.target.value)}
                />
              </div>
              
              <div className="mb-3">
                <h4 className="font-medium text-gray-900 mb-1">Price Range</h4>
                <div className="flex items-center gap-2">
                  <Input
                    type="number"
                    value={priceRange.min}
                    onChange={(e) => setPriceRange({ ...priceRange, min: Number(e.target.value) })}
                    placeholder="Min"
                    min={0}
                  />
                  <span className="text-gray-400">-</span>
                  <Input
                    type="number"
                    value={priceRange.max}
                    onChange={(e) => setPriceRange({ ...priceRange, max: Number(e.target.value) })}
                    placeholder="Max"
                    min={0}
                  />
                </div>
              </div>
              
              <div className="mb-3">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={onlyDiscounted}
                    onChange={(e) => setOnlyDiscounted(e.target.checked)}
                    className="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
                  />
                  <span className="ml-2 text-gray-700">On Sale</span>
                </label>
              </div>
            </div>
            
            <div className="flex gap-2">
              <Button variant="outline" onClick={resetFilters} className="flex-1">
                Reset
              </Button>
              <Button onClick={() => setIsFilterOpen(false)} className="flex-1">
                Apply
              </Button>
            </div>
          </div>
        )}
        
        {/* Products Grid */}
        <div className="flex-grow">
          {isLoading ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 animate-pulse">
              {[...Array(6)].map((_, index) => (
                <div key={index} className="bg-gray-200 rounded-lg aspect-square"></div>
              ))}
            </div>
          ) : products.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 mb-2">No products found</h3>
              <p className="text-gray-600 mb-4">Try adjusting your search or filter criteria</p>
              <Button variant="outline" onClick={resetFilters}>
                Reset Filters
              </Button>
            </div>
          ) : (
            <>
              <div className="mb-4">
                <p className="text-gray-600">
                  Showing {products.length} of {totalProducts} products
                </p>
              </div>
              
              {viewMode === 'grid' ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                  {products.map((product) => (
                    <ProductCard key={product.id} product={product} />
                  ))}
                </div>
              ) : (
                <div className="space-y-4">
                  {products.map((product) => (
                    <ProductCard key={product.id} product={product} layout="list" />
                  ))}
                </div>
              )}
              
              {/* Pagination */}
              {totalProducts > itemsPerPage && (
                <div className="mt-8 flex justify-center">
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                      disabled={currentPage === 1}
                    >
                      Previous
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => setCurrentPage(prev => prev + 1)}
                      disabled={currentPage * itemsPerPage >= totalProducts}
                    >
                      Next
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default ProductsPage;