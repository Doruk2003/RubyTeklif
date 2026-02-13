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
begin
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
begin
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

create or replace function public.update_product_with_audit_atomic(
  p_actor_id uuid,
  p_product_id uuid,
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
begin
  update public.products
  set
    name = p_name,
    price = p_price,
    vat_rate = p_vat_rate,
    item_type = p_item_type,
    category_id = p_category_id,
    active = p_active
  where id = p_product_id
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
    jsonb_build_object('name', p_name),
    now()
  );

  return query select v_product_id;
end;
$$;
