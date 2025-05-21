import React, { useState, useEffect } from 'react';
import { Plus, Search, Edit, Trash2, Package, X } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatCurrency } from '../../lib/utils';
import { toast } from 'react-hot-toast';

interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  inventory: number;
  category_id: string;
  discount?: number;
  featured: boolean;
  images: string[];
}

interface Category {
  id: string;
  name: string;
}

const AdminProductsPage = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);
  const [newProduct, setNewProduct] = useState({
    name: '',
    description: '',
    price: '',
    inventory: '',
    category_id: '',
    discount: '',
    featured: false,
    images: [] as string[]
  });
  const [imageUrls, setImageUrls] = useState<string[]>([]);
  const [isUploading, setIsUploading] = useState(false);

  useEffect(() => {
    fetchProducts();
    fetchCategories();
  }, []);

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsUploading(true);
    const newUrls: string[] = [];

    try {
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        const fileExt = file.name.split('.').pop();
        const fileName = `${Math.random().toString(36).substring(2)}.${fileExt}`;
        const filePath = `product-images/${fileName}`;

        const { error: uploadError } = await supabase.storage
          .from('products')
          .upload(filePath, file);

        if (uploadError) throw uploadError;

        const { data: urlData } = supabase.storage
          .from('products')
          .getPublicUrl(filePath);

        if (urlData) {
          newUrls.push(urlData.publicUrl);
        }
      }

      if (editingProduct) {
        setEditingProduct({
          ...editingProduct,
          images: [...editingProduct.images, ...newUrls]
        });
      } else {
        setNewProduct({
          ...newProduct,
          images: [...newProduct.images, ...newUrls]
        });
      }

      toast.success('Images uploaded successfully');
    } catch (error) {
      console.error('Error uploading images:', error);
      toast.error('Failed to upload images');
    } finally {
      setIsUploading(false);
    }
  };

  const handleRemoveImage = (index: number) => {
    if (editingProduct) {
      const newImages = [...editingProduct.images];
      newImages.splice(index, 1);
      setEditingProduct({ ...editingProduct, images: newImages });
    } else {
      const newImages = [...newProduct.images];
      newImages.splice(index, 1);
      setNewProduct({ ...newProduct, images: newImages });
    }
  };

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*, categories(name)');

      if (error) throw error;

      setProducts(data || []);
    } catch (error) {
      console.error('Error fetching products:', error);
      toast.error('Failed to load products');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('id, name');

      if (error) throw error;

      setCategories(data || []);
    } catch (error) {
      console.error('Error fetching categories:', error);
    }
  };

  const handleAddProduct = async () => {
    try {
      // Validate required fields
      if (!newProduct.name.trim()) {
        toast.error('Please enter a product name');
        return;
      }

      if (!newProduct.price || parseFloat(newProduct.price) <= 0) {
        toast.error('Please enter a valid price');
        return;
      }

      if (!newProduct.inventory || parseInt(newProduct.inventory) < 0) {
        toast.error('Please enter a valid inventory amount');
        return;
      }

      if (!newProduct.category_id) {
        toast.error('Please select a category');
        return;
      }

      const productData = {
        name: newProduct.name.trim(),
        description: newProduct.description.trim(),
        price: parseFloat(newProduct.price),
        inventory: parseInt(newProduct.inventory),
        category_id: newProduct.category_id,
        discount: newProduct.discount ? parseInt(newProduct.discount) : null,
        featured: newProduct.featured,
        images: newProduct.images.filter(img => img.trim() !== '')
      };

      const { error } = await supabase
        .from('products')
        .insert([productData]);

      if (error) throw error;

      toast.success('Product added successfully');
      setShowAddModal(false);
      setNewProduct({
        name: '',
        description: '',
        price: '',
        inventory: '',
        category_id: '',
        discount: '',
        featured: false,
        images: []
      });
      fetchProducts();
    } catch (error) {
      console.error('Error adding product:', error);
      toast.error('Failed to add product');
    }
  };

  const handleUpdateProduct = async (product: Product) => {
    try {
      // Validate required fields
      if (!product.name.trim()) {
        toast.error('Please enter a product name');
        return;
      }

      if (!product.price || product.price <= 0) {
        toast.error('Please enter a valid price');
        return;
      }

      if (!product.inventory || product.inventory < 0) {
        toast.error('Please enter a valid inventory amount');
        return;
      }

      if (!product.category_id) {
        toast.error('Please select a category');
        return;
      }

      const updateData = {
        name: product.name.trim(),
        description: product.description.trim(),
        price: product.price,
        inventory: product.inventory,
        category_id: product.category_id,
        discount: product.discount,
        featured: product.featured,
        images: product.images
      };

      const { error } = await supabase
        .from('products')
        .update(updateData)
        .eq('id', product.id);

      if (error) throw error;

      toast.success('Product updated successfully');
      setEditingProduct(null);
      fetchProducts();
    } catch (error) {
      console.error('Error updating product:', error);
      toast.error('Failed to update product');
    }
  };

  const handleDeleteProduct = async (productId: string) => {
    if (!confirm('Are you sure you want to delete this product?')) return;

    try {
      const { error } = await supabase
        .from('products')
        .delete()
        .eq('id', productId);

      if (error) throw error;

      toast.success('Product deleted successfully');
      fetchProducts();
    } catch (error) {
      console.error('Error deleting product:', error);
      toast.error('Failed to delete product');
    }
  };

  const filteredProducts = products.filter(product => {
    const matchesSearch = 
      product.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      product.description.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesCategory = categoryFilter === 'all' || product.category_id === categoryFilter;

    return matchesSearch && matchesCategory;
  });

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="h-24 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Manage Products</h1>
        <Button
          onClick={() => setShowAddModal(true)}
          leftIcon={<Plus className="h-5 w-5" />}
        >
          Add Product
        </Button>
      </div>

      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
            <Input
              placeholder="Search products..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              leftIcon={<Search className="h-5 w-5" />}
              className="flex-grow"
            />
            <Select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              options={[
                { value: 'all', label: 'All Categories' },
                ...categories.map(cat => ({
                  value: cat.id,
                  label: cat.name
                }))
              ]}
              className="w-full md:w-48"
            />
          </div>
        </CardContent>
      </Card>

      <div className="space-y-4">
        {filteredProducts.map((product) => (
          <Card key={product.id}>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-16 h-16 bg-gray-100 rounded-lg overflow-hidden">
                    {product.images[0] ? (
                      <img
                        src={product.images[0]}
                        alt={product.name}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <Package className="h-8 w-8 text-gray-400" />
                      </div>
                    )}
                  </div>
                  <div className="ml-4">
                    <h3 className="font-medium text-gray-900">{product.name}</h3>
                    <p className="text-sm text-gray-500">{formatCurrency(product.price)}</p>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge variant="secondary">
                        Stock: {product.inventory}
                      </Badge>
                      {product.discount && (
                        <Badge variant="danger">
                          {product.discount}% OFF
                        </Badge>
                      )}
                      {product.featured && (
                        <Badge variant="success">
                          Featured
                        </Badge>
                      )}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setEditingProduct(product)}
                  >
                    <Edit className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleDeleteProduct(product.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Add/Edit Product Modal */}
      {(showAddModal || editingProduct) && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <Card className="w-full max-w-2xl">
            <CardHeader>
              <CardTitle>
                {editingProduct ? 'Edit Product' : 'Add New Product'}
              </CardTitle>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                <Input
                  label="Name"
                  value={editingProduct?.name || newProduct.name}
                  onChange={(e) => editingProduct 
                    ? setEditingProduct({ ...editingProduct, name: e.target.value })
                    : setNewProduct({ ...newProduct, name: e.target.value })
                  }
                  required
                />
                <Input
                  label="Description"
                  value={editingProduct?.description || newProduct.description}
                  onChange={(e) => editingProduct
                    ? setEditingProduct({ ...editingProduct, description: e.target.value })
                    : setNewProduct({ ...newProduct, description: e.target.value })
                  }
                />
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <Input
                    label="Price"
                    type="number"
                    value={editingProduct?.price || newProduct.price}
                    onChange={(e) => editingProduct
                      ? setEditingProduct({ ...editingProduct, price: parseFloat(e.target.value) })
                      : setNewProduct({ ...newProduct, price: e.target.value })
                    }
                    required
                  />
                  <Input
                    label="Inventory"
                    type="number"
                    value={editingProduct?.inventory || newProduct.inventory}
                    onChange={(e) => editingProduct
                      ? setEditingProduct({ ...editingProduct, inventory: parseInt(e.target.value) })
                      : setNewProduct({ ...newProduct, inventory: e.target.value })
                    }
                    required
                  />
                  <Select
                    label="Category"
                    value={editingProduct?.category_id || newProduct.category_id}
                    onChange={(e) => editingProduct
                      ? setEditingProduct({ ...editingProduct, category_id: e.target.value })
                      : setNewProduct({ ...newProduct, category_id: e.target.value })
                    }
                    options={[
                      { value: '', label: 'Select a category' },
                      ...categories.map(cat => ({
                        value: cat.id,
                        label: cat.name
                      }))
                    ]}
                    required
                  />
                  <Input
                    label="Discount (%)"
                    type="number"
                    value={editingProduct?.discount || newProduct.discount}
                    onChange={(e) => editingProduct
                      ? setEditingProduct({ ...editingProduct, discount: parseInt(e.target.value) })
                      : setNewProduct({ ...newProduct, discount: e.target.value })
                    }
                  />
                </div>
                
                {/* Image Upload */}
                <div className="col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Product Images
                  </label>
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      {(editingProduct?.images || newProduct.images).map((image, index) => (
                        <div key={index} className="relative group">
                          <img
                            src={image}
                            alt={`Product image ${index + 1}`}
                            className="w-full h-32 object-cover rounded-lg"
                          />
                          <button
                            type="button"
                            onClick={() => handleRemoveImage(index)}
                            className="absolute top-2 right-2 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        </div>
                      ))}
                      <label className="border-2 border-dashed border-gray-300 rounded-lg p-4 h-32 flex flex-col items-center justify-center cursor-pointer hover:border-gray-400 transition-colors">
                        <input
                          type="file"
                          accept="image/*"
                          multiple
                          onChange={handleImageUpload}
                          className="hidden"
                        />
                        {isUploading ? (
                          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-gray-900"></div>
                        ) : (
                          <>
                            <Plus className="h-6 w-6 text-gray-400" />
                            <span className="mt-2 text-sm text-gray-500">Add Images</span>
                          </>
                        )}
                      </label>
                    </div>
                    <p className="text-sm text-gray-500">
                      Upload multiple product images. Supported formats: JPG, PNG, GIF
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={editingProduct?.featured || newProduct.featured}
                    onChange={(e) => editingProduct
                      ? setEditingProduct({ ...editingProduct, featured: e.target.checked })
                      : setNewProduct({ ...newProduct, featured: e.target.checked })
                    }
                    className="rounded border-gray-300"
                  />
                  <label>Featured Product</label>
                </div>
                <div className="flex justify-end gap-2 mt-6">
                  <Button
                    variant="outline"
                    onClick={() => {
                      setShowAddModal(false);
                      setEditingProduct(null);
                    }}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={() => editingProduct
                      ? handleUpdateProduct(editingProduct)
                      : handleAddProduct()
                    }
                  >
                    {editingProduct ? 'Update Product' : 'Add Product'}
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default AdminProductsPage;