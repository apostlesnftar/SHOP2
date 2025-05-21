/*
  # Fix storage bucket and policies
  
  1. Changes
    - Update bucket configuration without changing name
    - Recreate storage policies for admin access
*/

-- Update the products bucket configuration
UPDATE storage.buckets 
SET 
  public = true,
  file_size_limit = 52428800, -- 50MB limit
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
WHERE id = 'products';

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
DROP POLICY IF EXISTS "Only admins can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Only admins can update product images" ON storage.objects;
DROP POLICY IF EXISTS "Only admins can delete product images" ON storage.objects;

-- Create policies for the storage bucket
CREATE POLICY "Anyone can view product images"
ON storage.objects FOR SELECT
USING (bucket_id = 'products');

CREATE POLICY "Only admins can upload product images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'products' 
  AND auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM auth.users
    JOIN public.user_profiles ON user_profiles.id = auth.users.id
    WHERE auth.users.id = auth.uid()
    AND user_profiles.role = 'admin'
  )
);

CREATE POLICY "Only admins can update product images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'products'
  AND auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM auth.users
    JOIN public.user_profiles ON user_profiles.id = auth.users.id
    WHERE auth.users.id = auth.uid()
    AND user_profiles.role = 'admin'
  )
);

CREATE POLICY "Only admins can delete product images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'products'
  AND auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM auth.users
    JOIN public.user_profiles ON user_profiles.id = auth.users.id
    WHERE auth.users.id = auth.uid()
    AND user_profiles.role = 'admin'
  )
);