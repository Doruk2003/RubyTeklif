create or replace function public.update_category_with_audit_atomic(
  p_actor_id uuid,
  p_category_id uuid,
  p_code text,
  p_name text,
  p_active boolean
)
returns table (category_id uuid)
language plpgsql
security invoker
as $$
declare
  v_category_id uuid;
begin
  update public.categories
  set
    code = p_code,
    name = p_name,
    active = p_active
  where id = p_category_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_category_id;

  if v_category_id is null then
    raise exception 'Category not found or not allowed';
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
    'categories.update',
    p_actor_id,
    v_category_id::text,
    'category',
    jsonb_build_object('code', p_code, 'name', p_name),
    now()
  );

  return query select v_category_id;
end;
$$;

create or replace function public.archive_category_with_audit_atomic(
  p_actor_id uuid,
  p_category_id uuid
)
returns table (category_id uuid)
language plpgsql
security invoker
as $$
declare
  v_category_id uuid;
begin
  update public.categories
  set deleted_at = now()
  where id = p_category_id
    and user_id = p_actor_id
    and deleted_at is null
  returning id into v_category_id;

  if v_category_id is null then
    raise exception 'Category not found or not allowed';
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
    'categories.archive',
    p_actor_id,
    v_category_id::text,
    'category',
    '{}'::jsonb,
    now()
  );

  return query select v_category_id;
end;
$$;

create or replace function public.restore_category_with_audit_atomic(
  p_actor_id uuid,
  p_category_id uuid
)
returns table (category_id uuid)
language plpgsql
security invoker
as $$
declare
  v_category_id uuid;
begin
  update public.categories
  set deleted_at = null
  where id = p_category_id
    and user_id = p_actor_id
    and deleted_at is not null
  returning id into v_category_id;

  if v_category_id is null then
    raise exception 'Category not found or not allowed';
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
    'categories.restore',
    p_actor_id,
    v_category_id::text,
    'category',
    '{}'::jsonb,
    now()
  );

  return query select v_category_id;
end;
$$;
