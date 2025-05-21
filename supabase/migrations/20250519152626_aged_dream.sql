-- Drop all existing storage policies to start fresh
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Admin Insert" ON storage.objects;
DROP POLICY IF EXISTS "Admin Update" ON storage.objects;
DROP POLICY IF EXISTS "Admin Delete" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for product images" ON storage.objects;
DROP POLICY IF EXISTS "Admin users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Admin users can update product images" ON storage.objects;
DROP POLICY IF EXISTS "Admin users can delete product images" ON storage.objects;
DROP POLICY IF EXISTS "Product images are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own product images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
DROP POLICY IF EXISTS "Only admins can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Only admins can update product images" ON storage.objects;
DROP POLICY IF EXISTS "Only admins can delete product images" ON storage.objects;

-- Drop any existing storage admin functions
DROP FUNCTION IF EXISTS public.is_storage_admin();

-- Create storage admin check function
CREATE OR REPLACE FUNCTION public.is_storage_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the products bucket configuration
UPDATE storage.buckets 
SET 
  public = true,
  file_size_limit = 52428800, -- 50MB limit
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
WHERE id = 'products';

-- Create new storage policies
CREATE POLICY "Public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'products');

CREATE POLICY "Admin insert access"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'products' 
  AND public.is_storage_admin()
);

CREATE POLICY "Admin update access"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'products'
  AND public.is_storage_admin()
);

CREATE POLICY "Admin delete access"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'products'
  AND public.is_storage_admin()
);