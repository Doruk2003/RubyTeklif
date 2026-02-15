create or replace function public.create_category_with_audit_atomic(
  p_actor_id uuid,
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
  insert into public.categories (
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
  returning id into v_category_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'categories.create',
    p_actor_id,
    v_category_id::text,
    'category',
    jsonb_build_object('code', p_code, 'name', p_name),
    now()
  );

  return query select v_category_id;
end;
$$;
