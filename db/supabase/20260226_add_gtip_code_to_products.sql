-- db/supabase/20260226_add_gtip_code_to_products.sql

-- 1. Add column to products table
alter table public.products
  add column if not exists gtip_code text check (char_length(gtip_code) <= 50);

-- 2. Drop existing functions to update signatures
drop function if exists public.create_product_with_audit_atomic(
  uuid, text, text, text, text, numeric, numeric, numeric, numeric, numeric, text, uuid, uuid, uuid, text, boolean, boolean, boolean, boolean
);

drop function if exists public.update_product_with_audit_atomic(
  uuid, uuid, text, text, text, text, numeric, numeric, numeric, numeric, numeric, text, uuid, uuid, uuid, text, boolean, boolean, boolean, boolean
);

-- 3. Recreate create_product function with gtip_code
create or replace function public.create_product_with_audit_atomic(
  p_actor_id uuid,
  p_sku text,
  p_name text,
  p_description text,
  p_barcode text,
  p_gtip_code text,
  p_price numeric,
  p_cost_price numeric,
  p_stock_quantity numeric,
  p_min_stock_level numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
  p_brand_id uuid,
  p_currency_id uuid,
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
  v_currency_ok boolean;
  v_sku text;
  v_category_code text;
  v_prefix text;
  v_next_number integer;
  v_description text;
  v_barcode text;
  v_gtip text;
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

  if p_currency_id is not null then
    select exists (
      select 1
      from public.currencies cur
      where cur.id = p_currency_id
        and cur.user_id = p_actor_id
        and cur.deleted_at is null
    ) into v_currency_ok;

    if coalesce(v_currency_ok, false) is not true then
      raise exception 'Currency not found or not allowed';
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

  v_description := nullif(btrim(coalesce(p_description, '')), '');
  v_barcode := nullif(upper(btrim(coalesce(p_barcode, ''))), '');
  v_gtip := nullif(upper(btrim(coalesce(p_gtip_code, ''))), '');

  insert into public.products (
    user_id,
    sku,
    name,
    description,
    barcode,
    gtip_code,
    price,
    cost_price,
    stock_quantity,
    min_stock_level,
    vat_rate,
    item_type,
    category_id,
    brand_id,
    currency_id,
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
    v_description,
    v_barcode,
    v_gtip,
    p_price,
    coalesce(p_cost_price, 0),
    greatest(coalesce(p_stock_quantity, 0), 0),
    greatest(coalesce(p_min_stock_level, 0), 0),
    p_vat_rate,
    p_item_type,
    p_category_id,
    p_brand_id,
    p_currency_id,
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
    jsonb_build_object('sku', v_sku, 'name', p_name, 'barcode', v_barcode, 'gtip_code', v_gtip),
    now()
  );

  return query select v_product_id;
end;
$$;

-- 4. Recreate update_product function with gtip_code
create or replace function public.update_product_with_audit_atomic(
  p_actor_id uuid,
  p_product_id uuid,
  p_sku text,
  p_name text,
  p_description text,
  p_barcode text,
  p_gtip_code text,
  p_price numeric,
  p_cost_price numeric,
  p_stock_quantity numeric,
  p_min_stock_level numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
  p_brand_id uuid,
  p_currency_id uuid,
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
  v_currency_ok boolean;
  v_sku text;
  v_category_code text;
  v_prefix text;
  v_next_number integer;
  v_description text;
  v_barcode text;
  v_gtip text;
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

  if p_currency_id is not null then
    select exists (
      select 1
      from public.currencies cur
      where cur.id = p_currency_id
        and cur.user_id = p_actor_id
        and cur.deleted_at is null
    ) into v_currency_ok;

    if coalesce(v_currency_ok, false) is not true then
      raise exception 'Currency not found or not allowed';
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

  v_description := nullif(btrim(coalesce(p_description, '')), '');
  v_barcode := nullif(upper(btrim(coalesce(p_barcode, ''))), '');
  v_gtip := nullif(upper(btrim(coalesce(p_gtip_code, ''))), '');

  update public.products
  set
    sku = v_sku,
    name = p_name,
    description = v_description,
    barcode = v_barcode,
    gtip_code = v_gtip,
    price = p_price,
    cost_price = coalesce(p_cost_price, 0),
    stock_quantity = greatest(coalesce(p_stock_quantity, 0), 0),
    min_stock_level = greatest(coalesce(p_min_stock_level, 0), 0),
    vat_rate = p_vat_rate,
    item_type = p_item_type,
    category_id = p_category_id,
    brand_id = p_brand_id,
    currency_id = p_currency_id,
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
    jsonb_build_object('sku', v_sku, 'name', p_name, 'barcode', v_barcode, 'gtip_code', v_gtip),
    now()
  );

  return query select v_product_id;
end;
$$;
