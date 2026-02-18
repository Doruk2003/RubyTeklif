alter table public.products
  add column if not exists sku text,
  add column if not exists unit text;

update public.products
set sku = coalesce(
  nullif(btrim(sku), ''),
  'PRD-' || upper(replace(id::text, '-', ''))
)
where sku is null or btrim(sku) = '';

update public.products
set unit = coalesce(nullif(lower(btrim(unit)), ''), 'adet')
where unit is null or btrim(unit) = '';

alter table public.products
  alter column sku set not null,
  alter column unit set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_unit_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
      add constraint products_unit_check
      check (unit in ('adet', 'm', 'm2', 'kg', 'lt', 'saat', 'paket'));
  end if;
end $$;

create unique index if not exists products_user_sku_key
  on public.products (user_id, upper(sku));

drop function if exists public.create_product_with_audit_atomic(uuid, text, numeric, numeric, text, uuid, boolean);
drop function if exists public.update_product_with_audit_atomic(uuid, uuid, text, numeric, numeric, text, uuid, boolean);

create or replace function public.create_product_with_audit_atomic(
  p_actor_id uuid,
  p_sku text,
  p_name text,
  p_price numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
  p_unit text,
  p_active boolean
)
returns table (product_id uuid)
language plpgsql
security invoker
as $$
declare
  v_product_id uuid;
  v_category_ok boolean;
begin
  select exists (
    select 1
    from public.categories c
    where c.id = p_category_id
      and c.user_id = p_actor_id
      and c.deleted_at is null
  ) into v_category_ok;

  if coalesce(v_category_ok, false) is not true then
    raise exception 'Category not found or not allowed';
  end if;

  insert into public.products (
    user_id,
    sku,
    name,
    price,
    vat_rate,
    item_type,
    category_id,
    unit,
    active
  )
  values (
    p_actor_id,
    upper(btrim(p_sku)),
    p_name,
    p_price,
    p_vat_rate,
    p_item_type,
    p_category_id,
    lower(btrim(p_unit)),
    p_active
  )
  returning id into v_product_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'products.create',
    p_actor_id,
    v_product_id::text,
    'product',
    jsonb_build_object('sku', upper(btrim(p_sku)), 'name', p_name),
    now()
  );

  return query select v_product_id;
end;
$$;

create or replace function public.update_product_with_audit_atomic(
  p_actor_id uuid,
  p_product_id uuid,
  p_sku text,
  p_name text,
  p_price numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
  p_unit text,
  p_active boolean
)
returns table (product_id uuid)
language plpgsql
security invoker
as $$
declare
  v_product_id uuid;
  v_category_ok boolean;
begin
  select exists (
    select 1
    from public.categories c
    where c.id = p_category_id
      and c.user_id = p_actor_id
      and c.deleted_at is null
  ) into v_category_ok;

  if coalesce(v_category_ok, false) is not true then
    raise exception 'Category not found or not allowed';
  end if;

  update public.products
  set
    sku = upper(btrim(p_sku)),
    name = p_name,
    price = p_price,
    vat_rate = p_vat_rate,
    item_type = p_item_type,
    category_id = p_category_id,
    unit = lower(btrim(p_unit)),
    active = p_active
  where id = p_product_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_product_id;

  if v_product_id is null then
    raise exception 'Product not found or not allowed';
  end if;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'products.update',
    p_actor_id,
    v_product_id::text,
    'product',
    jsonb_build_object('sku', upper(btrim(p_sku)), 'name', p_name),
    now()
  );

  return query select v_product_id;
end;
$$;
