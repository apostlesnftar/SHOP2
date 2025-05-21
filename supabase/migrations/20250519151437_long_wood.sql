/*
  # Create storage bucket for product images
  
  1. Storage
    - Create products bucket for storing product images
    - Set up RLS policies for bucket access
    - Allow public read access
    - Restrict write access to admin users
*/

-- Create the products bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'Product Images',
  true,
  52428800, -- 50MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[]
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow public read access to all files in the products bucket
CREATE POLICY "Public read access for product images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- Allow admins to upload files to the products bucket
CREATE POLICY "Admin users can upload product images"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (
  bucket_id = 'product-images' 
  AND auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM auth.users
    JOIN public.user_profiles ON user_profiles.id = auth.uid()
    WHERE user_profiles.role = 'admin'
  )
);

-- Allow admins to update files in the products bucket
CREATE POLICY "Admin users can update product images"
ON storage.objects
FOR UPDATE
TO public
USING (
  bucket_id = 'product-images'
  AND auth.role() = 'authenticated'
  AND EXISTS (
    SELECT 1 FROM auth.users
    JOIN public.user_profiles ON user_profiles.id = auth.uid()
    WHERE user_profiles.role = 'admin'
  )
);

-- Allow admins to delete files from the products bucket
CREATE POLICY "Admin users can delete product images"
ON storage.objects
FOR DELETE
TO public
USING (
  bucket_id = 'product-images'
  AND auth.role() = 'authenticated'
  AND EXISTS (
    SELECT 1 FROM auth.users
    JOIN public.user_profiles ON user_profiles.id = auth.uid()
    WHERE user_profiles.role = 'admin'
  )
);