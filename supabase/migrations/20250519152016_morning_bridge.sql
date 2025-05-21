-- Create storage bucket function
create or replace function public.create_products_bucket()
returns void as $$
begin
  insert into storage.buckets (id, name, public)
  values ('products', 'products', true)
  on conflict (id) do nothing;
end;
$$ language plpgsql security definer;

-- Create the bucket
select public.create_products_bucket();

-- Create policy function for admin check
create or replace function public.is_storage_admin()
returns boolean as $$
begin
  return exists (
    select 1
    from auth.users
    join public.user_profiles on user_profiles.id = auth.uid()
    where user_profiles.role = 'admin'
  );
end;
$$ language plpgsql security definer;

-- Create policies
create policy "Public Access"
on storage.objects for select
to public
using ( bucket_id = 'products' );

create policy "Admin Insert"
on storage.objects for insert
to public
with check (
  bucket_id = 'products'
  and auth.role() = 'authenticated'
  and public.is_storage_admin()
);

create policy "Admin Update"
on storage.objects for update
to public
using (
  bucket_id = 'products'
  and auth.role() = 'authenticated'
  and public.is_storage_admin()
);

create policy "Admin Delete"
on storage.objects for delete
to public
using (
  bucket_id = 'products'
  and auth.role() = 'authenticated'
  and public.is_storage_admin()
);