create or replace function public.update_company_with_audit_atomic(
  p_actor_id uuid,
  p_company_id uuid,
  p_name text,
  p_tax_number text,
  p_tax_office text,
  p_authorized_person text,
  p_phone text,
  p_email text,
  p_address text,
  p_active boolean
)
returns table (company_id uuid)
language plpgsql
security invoker
as $$
declare
  v_company_id uuid;
begin
  update public.companies
  set
    name = p_name,
    tax_number = p_tax_number,
    tax_office = p_tax_office,
    authorized_person = p_authorized_person,
    phone = p_phone,
    email = p_email,
    address = p_address,
    active = p_active
  where id = p_company_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_company_id;

  if v_company_id is null then
    raise exception 'Company not found or not allowed';
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
    'companies.update',
    p_actor_id,
    v_company_id::text,
    'company',
    jsonb_build_object('name', p_name),
    now()
  );

  return query select v_company_id;
end;
$$;

create or replace function public.archive_company_with_audit_atomic(
  p_actor_id uuid,
  p_company_id uuid
)
returns table (company_id uuid)
language plpgsql
security invoker
as $$
declare
  v_company_id uuid;
begin
  update public.companies
  set deleted_at = now()
  where id = p_company_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_company_id;

  if v_company_id is null then
    raise exception 'Company not found or not allowed';
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
    'companies.archive',
    p_actor_id,
    v_company_id::text,
    'company',
    '{}'::jsonb,
    now()
  );

  return query select v_company_id;
end;
$$;

create or replace function public.restore_company_with_audit_atomic(
  p_actor_id uuid,
  p_company_id uuid
)
returns table (company_id uuid)
language plpgsql
security invoker
as $$
declare
  v_company_id uuid;
begin
  update public.companies
  set deleted_at = null
  where id = p_company_id
    and user_id = p_actor_id
    and deleted_at is not null
  returning id into v_company_id;

  if v_company_id is null then
    raise exception 'Company not found or not allowed';
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
    'companies.restore',
    p_actor_id,
    v_company_id::text,
    'company',
    '{}'::jsonb,
    now()
  );

  return query select v_company_id;
end;
$$;

create or replace function public.update_currency_with_audit_atomic(
  p_actor_id uuid,
  p_currency_id uuid,
  p_code text,
  p_name text,
  p_symbol text,
  p_rate_to_try numeric,
  p_active boolean
)
returns table (currency_id uuid)
language plpgsql
security invoker
as $$
declare
  v_currency_id uuid;
begin
  update public.currencies
  set
    code = p_code,
    name = p_name,
    symbol = p_symbol,
    rate_to_try = p_rate_to_try,
    active = p_active
  where id = p_currency_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_currency_id;

  if v_currency_id is null then
    raise exception 'Currency not found or not allowed';
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
    'currencies.update',
    p_actor_id,
    v_currency_id::text,
    'currency',
    jsonb_build_object('code', p_code),
    now()
  );

  return query select v_currency_id;
end;
$$;

create or replace function public.archive_currency_with_audit_atomic(
  p_actor_id uuid,
  p_currency_id uuid
)
returns table (currency_id uuid)
language plpgsql
security invoker
as $$
declare
  v_currency_id uuid;
begin
  update public.currencies
  set deleted_at = now()
  where id = p_currency_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_currency_id;

  if v_currency_id is null then
    raise exception 'Currency not found or not allowed';
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
    'currencies.archive',
    p_actor_id,
    v_currency_id::text,
    'currency',
    '{}'::jsonb,
    now()
  );

  return query select v_currency_id;
end;
$$;

create or replace function public.restore_currency_with_audit_atomic(
  p_actor_id uuid,
  p_currency_id uuid
)
returns table (currency_id uuid)
language plpgsql
security invoker
as $$
declare
  v_currency_id uuid;
begin
  update public.currencies
  set deleted_at = null
  where id = p_currency_id
    and user_id = p_actor_id
    and deleted_at is not null
  returning id into v_currency_id;

  if v_currency_id is null then
    raise exception 'Currency not found or not allowed';
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
    'currencies.restore',
    p_actor_id,
    v_currency_id::text,
    'currency',
    '{}'::jsonb,
    now()
  );

  return query select v_currency_id;
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
    jsonb_build_object('name', p_name),
    now()
  );

  return query select v_product_id;
end;
$$;

create or replace function public.archive_product_with_audit_atomic(
  p_actor_id uuid,
  p_product_id uuid
)
returns table (product_id uuid)
language plpgsql
security invoker
as $$
declare
  v_product_id uuid;
begin
  update public.products
  set deleted_at = now()
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
    'products.archive',
    p_actor_id,
    v_product_id::text,
    'product',
    '{}'::jsonb,
    now()
  );

  return query select v_product_id;
end;
$$;

create or replace function public.restore_product_with_audit_atomic(
  p_actor_id uuid,
  p_product_id uuid
)
returns table (product_id uuid)
language plpgsql
security invoker
as $$
declare
  v_product_id uuid;
begin
  update public.products
  set deleted_at = null
  where id = p_product_id
    and user_id = p_actor_id
    and deleted_at is not null
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
    'products.restore',
    p_actor_id,
    v_product_id::text,
    'product',
    '{}'::jsonb,
    now()
  );

  return query select v_product_id;
end;
$$;

create or replace function public.archive_offer_with_items_and_audit_atomic(
  p_actor_id uuid,
  p_offer_id uuid
)
returns table (offer_id uuid)
language plpgsql
security invoker
as $$
declare
  v_offer_id uuid;
begin
  update public.offers
  set deleted_at = now()
  where id = p_offer_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_offer_id;

  if v_offer_id is null then
    raise exception 'Offer not found or not allowed';
  end if;

  update public.offer_items
  set deleted_at = now()
  where offer_id = v_offer_id
    and user_id = p_actor_id
    and deleted_at is null;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'offers.archive',
    p_actor_id,
    v_offer_id::text,
    'offer',
    '{}'::jsonb,
    now()
  );

  return query select v_offer_id;
end;
$$;

create or replace function public.restore_offer_with_items_and_audit_atomic(
  p_actor_id uuid,
  p_offer_id uuid
)
returns table (offer_id uuid)
language plpgsql
security invoker
as $$
declare
  v_offer_id uuid;
begin
  update public.offers
  set deleted_at = null
  where id = p_offer_id
    and user_id = p_actor_id
    and deleted_at is not null
  returning id into v_offer_id;

  if v_offer_id is null then
    raise exception 'Offer not found or not allowed';
  end if;

  update public.offer_items
  set deleted_at = null
  where offer_id = v_offer_id
    and user_id = p_actor_id
    and deleted_at is not null;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'offers.restore',
    p_actor_id,
    v_offer_id::text,
    'offer',
    '{}'::jsonb,
    now()
  );

  return query select v_offer_id;
end;
$$;
