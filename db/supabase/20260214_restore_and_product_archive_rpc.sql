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
