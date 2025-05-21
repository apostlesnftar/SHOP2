import { supabase } from '../lib/supabase';
import { Product, Category } from '../types';

// Get all products with pagination and filters
export const getProducts = async (options?: {
  page?: number;
  limit?: number;
  category?: string;
  search?: string;
  featured?: boolean;
  minPrice?: number;
  maxPrice?: number;
  onlyDiscounted?: boolean;
  sortBy?: string;
}): Promise<{ data: Product[]; count: number }> => {
  try {
    let query = supabase
      .from('products')
      .select('*', { count: 'exact' });
    
    // Apply filters
    if (options?.category) {
      query = query.eq('category_id', options.category);
    }
    
    if (options?.search) {
      query = query.or(`name.ilike.%${options.search}%,description.ilike.%${options.search}%`);
    }
    
    if (options?.featured) {
      query = query.eq('featured', true);
    }
    
    if (options?.minPrice !== undefined) {
      query = query.gte('price', options.minPrice);
    }
    
    if (options?.maxPrice !== undefined) {
      query = query.lte('price', options.maxPrice);
    }
    
    if (options?.onlyDiscounted) {
      query = query.gt('discount', 0);
    }
    
    // Apply sorting
    if (options?.sortBy) {
      switch (options.sortBy) {
        case 'price-low':
          query = query.order('price', { ascending: true });
          break;
        case 'price-high':
          query = query.order('price', { ascending: false });
          break;
        case 'newest':
          query = query.order('created_at', { ascending: false });
          break;
        default:
          query = query.order('created_at', { ascending: false });
      }
    } else {
      query = query.order('created_at', { ascending: false });
    }
    
    // Apply pagination
    if (options?.page && options?.limit) {
      const start = (options.page - 1) * options.limit;
      query = query.range(start, start + options.limit - 1);
    }
    
    const { data, error, count } = await query;
    
    if (error) throw error;
    
    return {
      data: (data || []).map(product => ({
        id: product.id,
        name: product.name,
        description: product.description || '',
        price: product.price,
        images: product.images,
        categoryId: product.category_id || '',
        inventory: product.inventory,
        discount: product.discount || undefined,
        featured: product.featured || false,
        createdAt: product.created_at,
        updatedAt: product.updated_at
      })),
      count: count || 0
    };
  } catch (error) {
    console.error('Error fetching products:', error);
    throw error;
  }
};
// Get all categories
export const getAllCategories = async (): Promise<Category[]> => {
  const { data, error } = await supabase
    .from('categories')
    .select('*')
    .order('name');
  
  if (error) throw error;
  
  return (data || []).map(category => ({
    id: category.id,
    name: category.name,
    description: category.description || '',
    imageUrl: category.image_url || '',
    createdAt: category.created_at,
    updatedAt: category.updated_at
  }));
};

// Get category by ID
export const getCategoryById = async (id: string): Promise<Category | null> => {
  const { data, error } = await supabase
    .from('categories')
    .select('*')
    .eq('id', id)
    .single();
  
  if (error || !data) return null;
  
  return {
    id: data.id,
    name: data.name,
    description: data.description || '',
    imageUrl: data.image_url || '',
    createdAt: data.created_at,
    updatedAt: data.updated_at
  };
};

// Get all products
export const getAllProducts = async (): Promise<Product[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(product => ({
    id: product.id,
    name: product.name,
    description: product.description || '',
    price: product.price,
    images: product.images,
    categoryId: product.category_id || '',
    inventory: product.inventory,
    discount: product.discount || undefined,
    featured: product.featured || false,
    createdAt: product.created_at,
    updatedAt: product.updated_at
  }));
};

// Get product by ID
export const getProductById = async (id: string): Promise<Product | null> => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('id', id)
    .single();
  
  if (error || !data) return null;
  
  return {
    id: data.id,
    name: data.name,
    description: data.description || '',
    price: data.price,
    images: data.images,
    categoryId: data.category_id || '',
    inventory: data.inventory,
    discount: data.discount || undefined,
    featured: data.featured || false,
    createdAt: data.created_at,
    updatedAt: data.updated_at
  };
};

// Get featured products
export const getFeaturedProducts = async (): Promise<Product[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('featured', true)
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(product => ({
    id: product.id,
    name: product.name,
    description: product.description || '',
    price: product.price,
    images: product.images,
    categoryId: product.category_id || '',
    inventory: product.inventory,
    discount: product.discount || undefined,
    featured: product.featured || false,
    createdAt: product.created_at,
    updatedAt: product.updated_at
  }));
};

// Search products
export const searchProducts = async (query: string): Promise<Product[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .or(`name.ilike.%${query}%,description.ilike.%${query}%`)
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(product => ({
    id: product.id,
    name: product.name,
    description: product.description || '',
    price: product.price,
    images: product.images,
    categoryId: product.category_id || '',
    inventory: product.inventory,
    discount: product.discount || undefined,
    featured: product.featured || false,
    createdAt: product.created_at,
    updatedAt: product.updated_at
  }));
};

// Get products by category
export const getProductsByCategory = async (categoryId: string): Promise<Product[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('category_id', categoryId)
    .order('created_at', { ascending: false });
  
  if (error) throw error;
  
  return (data || []).map(product => ({
    id: product.id,
    name: product.name,
    description: product.description || '',
    price: product.price,
    images: product.images,
    categoryId: product.category_id || '',
    inventory: product.inventory,
    discount: product.discount || undefined,
    featured: product.featured || false,
    createdAt: product.created_at,
    updatedAt: product.updated_at
  }));
};

// For admin use - Create product
export const createProduct = async (product: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>): Promise<Product> => {
  const { data, error } = await supabase
    .from('products')
    .insert({
      name: product.name,
      description: product.description,
      price: product.price,
      images: product.images,
      category_id: product.categoryId,
      inventory: product.inventory,
      discount: product.discount,
      featured: product.featured
    })
    .select()
    .single();
  
  if (error) throw error;
  
  return {
    id: data.id,
    name: data.name,
    description: data.description || '',
    price: data.price,
    images: data.images,
    categoryId: data.category_id || '',
    inventory: data.inventory,
    discount: data.discount || undefined,
    featured: data.featured || false,
    createdAt: data.created_at,
    updatedAt: data.updated_at
  };
};

// For admin use - Update product
export const updateProduct = async (id: string, updates: Partial<Omit<Product, 'id' | 'createdAt' | 'updatedAt'>>): Promise<Product> => {
  const { data, error } = await supabase
    .from('products')
    .update({
      name: updates.name,
      description: updates.description,
      price: updates.price,
      images: updates.images,
      category_id: updates.categoryId,
      inventory: updates.inventory,
      discount: updates.discount,
      featured: updates.featured
    })
    .eq('id', id)
    .select()
    .single();
  
  if (error) throw error;
  
  return {
    id: data.id,
    name: data.name,
    description: data.description || '',
    price: data.price,
    images: data.images,
    categoryId: data.category_id || '',
    inventory: data.inventory,
    discount: data.discount || undefined,
    featured: data.featured || false,
    createdAt: data.created_at,
    updatedAt: data.updated_at
  };
};

// For admin use - Delete product
export const deleteProduct = async (id: string): Promise<void> => {
  const { error } = await supabase
    .from('products')
    .delete()
    .eq('id', id);
  
  if (error) throw error;
};