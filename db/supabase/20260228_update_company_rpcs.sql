-- Update create_company_with_audit_atomic to include description, city, country
create or replace function public.create_company_with_audit_atomic(
  p_actor_id uuid,
  p_name text,
  p_tax_number text,
  p_tax_office text,
  p_authorized_person text,
  p_phone text,
  p_email text,
  p_address text,
  p_active boolean,
  p_description text default null,
  p_city text default null,
  p_country text default null
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
    description,
    city,
    country,
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
    p_description,
    p_city,
    p_country,
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

-- Update update_company_with_audit_atomic to include description, city, country
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
  p_active boolean,
  p_description text default null,
  p_city text default null,
  p_country text default null
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
    description = p_description,
    city = p_city,
    country = p_country,
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
