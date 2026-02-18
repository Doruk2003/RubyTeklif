create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  product_id uuid not null references public.products(id) on delete cascade,
  storage_path text not null,
  file_name text,
  content_type text,
  byte_size bigint,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists product_images_product_id_idx on public.product_images(product_id);
create index if not exists product_images_user_id_idx on public.product_images(user_id);
create index if not exists product_images_sort_idx on public.product_images(product_id, sort_order);
create index if not exists product_images_deleted_at_idx on public.product_images(deleted_at);

alter table public.product_images enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do nothing;

drop policy if exists product_images_bucket_read on storage.objects;
create policy product_images_bucket_read
on storage.objects for select
using (bucket_id = 'product-images');

drop policy if exists product_images_bucket_insert on storage.objects;
create policy product_images_bucket_insert
on storage.objects for insert
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists product_images_bucket_update on storage.objects;
create policy product_images_bucket_update
on storage.objects for update
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists product_images_bucket_delete on storage.objects;
create policy product_images_bucket_delete
on storage.objects for delete
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists product_images_owner_read on public.product_images;
create policy product_images_owner_read
on public.product_images for select
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists product_images_owner_insert on public.product_images;
create policy product_images_owner_insert
on public.product_images for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists product_images_owner_update on public.product_images;
create policy product_images_owner_update
on public.product_images for update
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
)
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists product_images_owner_delete on public.product_images;
create policy product_images_owner_delete
on public.product_images for delete
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);
