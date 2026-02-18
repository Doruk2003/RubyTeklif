create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index if not exists brands_user_code_key on public.brands(user_id, code);
create unique index if not exists brands_user_name_key on public.brands(user_id, name);
create index if not exists brands_user_active_idx on public.brands(user_id, active);
create index if not exists brands_deleted_at_idx on public.brands(deleted_at);

alter table public.brands enable row level security;

drop policy if exists brands_owner_read on public.brands;
create policy brands_owner_read
on public.brands for select
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists brands_owner_insert on public.brands;
create policy brands_owner_insert
on public.brands for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists brands_owner_update on public.brands;
create policy brands_owner_update
on public.brands for update
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

drop policy if exists brands_owner_delete on public.brands;
create policy brands_owner_delete
on public.brands for delete
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

alter table public.products
  add column if not exists brand_id uuid,
  add column if not exists is_stock_item boolean not null default true,
  add column if not exists cost_price numeric not null default 0,
  add column if not exists sale_price_vat_included boolean not null default false,
  add column if not exists cost_price_vat_included boolean not null default false;

create index if not exists products_brand_id_idx on public.products(brand_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_brand_id_fkey'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
      add constraint products_brand_id_fkey
      foreign key (brand_id) references public.brands(id)
      on delete set null;
  end if;
end $$;

create or replace function public.create_brand_with_audit_atomic(
  p_actor_id uuid,
  p_code text,
  p_name text,
  p_active boolean
)
returns table (brand_id uuid)
language plpgsql
security invoker
as $$
declare
  v_brand_id uuid;
begin
  insert into public.brands (
    user_id,
    code,
    name,
    active
  )
  values (
    p_actor_id,
    p_code,
    p_name,
    p_active
  )
  returning id into v_brand_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'brands.create',
    p_actor_id,
    v_brand_id::text,
    'brand',
    jsonb_build_object('code', p_code, 'name', p_name),
    now()
  );

  return query select v_brand_id;
end;
$$;

drop function if exists public.create_product_with_audit_atomic(uuid, text, text, numeric, numeric, text, uuid, text, boolean);
drop function if exists public.update_product_with_audit_atomic(uuid, uuid, text, text, numeric, numeric, text, uuid, text, boolean);

create or replace function public.create_product_with_audit_atomic(
  p_actor_id uuid,
  p_sku text,
  p_name text,
  p_price numeric,
  p_cost_price numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
  p_brand_id uuid,
  p_unit text,
  p_is_stock_item boolean,
  p_sale_price_vat_included boolean,
  p_cost_price_vat_included boolean,
  p_active boolean
)
returns table (product_id uuid)
language plpgsql
security invoker
as $$
declare
  v_product_id uuid;
  v_brand_ok boolean;
  v_sku text;
  v_category_code text;
  v_prefix text;
  v_next_number integer;
begin
  select c.code
    into v_category_code
  from public.categories c
  where c.id = p_category_id
    and c.user_id = p_actor_id
    and c.deleted_at is null;

  if v_category_code is null then
    raise exception 'Category not found or not allowed';
  end if;

  if p_brand_id is not null then
    select exists (
      select 1
      from public.brands b
      where b.id = p_brand_id
        and b.user_id = p_actor_id
        and b.deleted_at is null
    ) into v_brand_ok;

    if coalesce(v_brand_ok, false) is not true then
      raise exception 'Brand not found or not allowed';
    end if;
  end if;

  if nullif(btrim(p_sku), '') is null then
    v_prefix := left(
      upper(regexp_replace(coalesce(v_category_code, ''), '[^A-Za-z0-9]', '', 'g')) || 'XXX',
      3
    );

    select coalesce(max((substring(upper(sku) from '([0-9]{5})$'))::integer), 0) + 1
      into v_next_number
    from public.products
    where user_id = p_actor_id
      and upper(sku) ~ ('^' || v_prefix || '-[0-9]{5}$');

    v_sku := v_prefix || '-' || lpad(v_next_number::text, 5, '0');
  else
    v_sku := upper(btrim(p_sku));
  end if;

  insert into public.products (
    user_id,
    sku,
    name,
    price,
    cost_price,
    vat_rate,
    item_type,
    category_id,
    brand_id,
    unit,
    is_stock_item,
    sale_price_vat_included,
    cost_price_vat_included,
    active
  )
  values (
    p_actor_id,
    v_sku,
    p_name,
    p_price,
    coalesce(p_cost_price, 0),
    p_vat_rate,
    p_item_type,
    p_category_id,
    p_brand_id,
    lower(btrim(p_unit)),
    coalesce(p_is_stock_item, true),
    coalesce(p_sale_price_vat_included, false),
    coalesce(p_cost_price_vat_included, false),
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
    jsonb_build_object('sku', v_sku, 'name', p_name),
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
  p_cost_price numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
  p_brand_id uuid,
  p_unit text,
  p_is_stock_item boolean,
  p_sale_price_vat_included boolean,
  p_cost_price_vat_included boolean,
  p_active boolean
)
returns table (product_id uuid)
language plpgsql
security invoker
as $$
declare
  v_product_id uuid;
  v_brand_ok boolean;
  v_sku text;
  v_category_code text;
  v_prefix text;
  v_next_number integer;
begin
  select c.code
    into v_category_code
  from public.categories c
  where c.id = p_category_id
    and c.user_id = p_actor_id
    and c.deleted_at is null;

  if v_category_code is null then
    raise exception 'Category not found or not allowed';
  end if;

  if p_brand_id is not null then
    select exists (
      select 1
      from public.brands b
      where b.id = p_brand_id
        and b.user_id = p_actor_id
        and b.deleted_at is null
    ) into v_brand_ok;

    if coalesce(v_brand_ok, false) is not true then
      raise exception 'Brand not found or not allowed';
    end if;
  end if;

  if nullif(btrim(p_sku), '') is null then
    v_prefix := left(
      upper(regexp_replace(coalesce(v_category_code, ''), '[^A-Za-z0-9]', '', 'g')) || 'XXX',
      3
    );

    select coalesce(max((substring(upper(sku) from '([0-9]{5})$'))::integer), 0) + 1
      into v_next_number
    from public.products
    where user_id = p_actor_id
      and id <> p_product_id
      and upper(sku) ~ ('^' || v_prefix || '-[0-9]{5}$');

    v_sku := v_prefix || '-' || lpad(v_next_number::text, 5, '0');
  else
    v_sku := upper(btrim(p_sku));
  end if;

  update public.products
  set
    sku = v_sku,
    name = p_name,
    price = p_price,
    cost_price = coalesce(p_cost_price, 0),
    vat_rate = p_vat_rate,
    item_type = p_item_type,
    category_id = p_category_id,
    brand_id = p_brand_id,
    unit = lower(btrim(p_unit)),
    is_stock_item = coalesce(p_is_stock_item, true),
    sale_price_vat_included = coalesce(p_sale_price_vat_included, false),
    cost_price_vat_included = coalesce(p_cost_price_vat_included, false),
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
    jsonb_build_object('sku', v_sku, 'name', p_name),
    now()
  );

  return query select v_product_id;
end;
$$;
