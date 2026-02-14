create or replace function public.create_product_with_audit_atomic(
  p_actor_id uuid,
  p_name text,
  p_price numeric,
  p_vat_rate numeric,
  p_item_type text,
  p_category_id uuid,
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
    name,
    price,
    vat_rate,
    item_type,
    category_id,
    active
  )
  values (
    p_actor_id,
    p_name,
    p_price,
    p_vat_rate,
    p_item_type,
    p_category_id,
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
    jsonb_build_object('name', p_name),
    now()
  );

  return query select v_product_id;
end;
$$;

create or replace function public.create_offer_with_items_atomic(
  p_actor_id uuid,
  p_company_id uuid,
  p_offer_number text,
  p_offer_date date,
  p_status text,
  p_net_total numeric,
  p_vat_total numeric,
  p_gross_total numeric,
  p_items jsonb
)
returns table (offer_id uuid)
language plpgsql
security invoker
as $$
declare
  v_offer_id uuid;
  v_company_ok boolean;
  v_invalid_products_count bigint;
begin
  select exists (
    select 1
    from public.companies c
    where c.id = p_company_id
      and c.user_id = p_actor_id
      and c.deleted_at is null
  ) into v_company_ok;

  if coalesce(v_company_ok, false) is not true then
    raise exception 'Company not found or not allowed';
  end if;

  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'Items payload must be an array';
  end if;

  select count(*)::bigint
    into v_invalid_products_count
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) as item
  left join public.products p
    on p.id = (item->>'product_id')::uuid
   and p.user_id = p_actor_id
   and p.deleted_at is null
  where item->>'product_id' is null
     or p.id is null;

  if coalesce(v_invalid_products_count, 0) > 0 then
    raise exception 'One or more products are invalid or not allowed';
  end if;

  insert into public.offers (
    user_id,
    company_id,
    offer_number,
    offer_date,
    status,
    net_total,
    vat_total,
    gross_total
  )
  values (
    p_actor_id,
    p_company_id,
    p_offer_number,
    p_offer_date,
    p_status,
    p_net_total,
    p_vat_total,
    p_gross_total
  )
  returning id into v_offer_id;

  insert into public.offer_items (
    user_id,
    offer_id,
    product_id,
    description,
    quantity,
    unit_price,
    discount_rate,
    line_total
  )
  select
    p_actor_id,
    v_offer_id,
    (item->>'product_id')::uuid,
    item->>'description',
    coalesce((item->>'quantity')::numeric, 0),
    coalesce((item->>'unit_price')::numeric, 0),
    coalesce((item->>'discount_rate')::numeric, 0),
    coalesce((item->>'line_total')::numeric, 0)
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) as item;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'offers.create',
    p_actor_id,
    v_offer_id::text,
    'offer',
    jsonb_build_object('offer_number', p_offer_number),
    now()
  );

  return query select v_offer_id;
end;
$$;
