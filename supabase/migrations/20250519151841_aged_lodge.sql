/*
  # Create products storage bucket

  1. Changes
    - Creates a new storage bucket named 'products' for storing product images
    - Sets up public access policy for the bucket

  2. Security
    - Enables public read access to product images
    - Restricts write access to authenticated users
*/

-- Create the products bucket if it doesn't exist
insert into storage.buckets (id, name, public)
values ('products', 'products', true)
on conflict (id) do nothing;

-- Create policy to allow public access to product images
create policy "Product images are publicly accessible"
on storage.objects for select
to public
using ( bucket_id = 'products' );

-- Create policy to allow authenticated users to upload product images
create policy "Authenticated users can upload product images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'products'
  and owner = auth.uid()
);

-- Create policy to allow users to update their own product images
create policy "Users can update their own product images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'products'
  and owner = auth.uid()
)
with check (
  bucket_id = 'products'
  and owner = auth.uid()
);

-- Create policy to allow users to delete their own product images
create policy "Users can delete their own product images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'products'
  and owner = auth.uid()
);