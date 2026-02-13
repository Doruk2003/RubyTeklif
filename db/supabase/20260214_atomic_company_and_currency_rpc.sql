create or replace function public.create_company_with_audit_atomic(
  p_actor_id uuid,
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
  insert into public.companies (
    user_id,
    name,
    tax_number,
    tax_office,
    authorized_person,
    phone,
    email,
    address,
    active
  )
  values (
    p_actor_id,
    p_name,
    p_tax_number,
    p_tax_office,
    p_authorized_person,
    p_phone,
    p_email,
    p_address,
    p_active
  )
  returning id into v_company_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'companies.create',
    p_actor_id,
    v_company_id::text,
    'company',
    jsonb_build_object('name', p_name),
    now()
  );

  return query select v_company_id;
end;
$$;

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

create or replace function public.create_currency_with_audit_atomic(
  p_actor_id uuid,
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
  insert into public.currencies (
    user_id,
    code,
    name,
    symbol,
    rate_to_try,
    active
  )
  values (
    p_actor_id,
    p_code,
    p_name,
    p_symbol,
    p_rate_to_try,
    p_active
  )
  returning id into v_currency_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'currencies.create',
    p_actor_id,
    v_currency_id::text,
    'currency',
    jsonb_build_object('code', p_code),
    now()
  );

  return query select v_currency_id;
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
