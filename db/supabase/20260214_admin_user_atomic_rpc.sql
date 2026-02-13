create or replace function public.admin_update_user_role_with_audit_atomic(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_role text
)
returns table (user_id uuid)
language plpgsql
security invoker
as $$
declare
  v_actor_role text;
  v_actor_active boolean;
  v_target_role text;
  v_target_active boolean;
  v_active_admin_count bigint;
  v_user_id uuid;
begin
  select role, active
    into v_actor_role, v_actor_active
  from public.users
  where id = p_actor_id;

  if coalesce(v_actor_active, false) is not true or v_actor_role <> 'admin' then
    raise exception 'Only active admin can perform this action';
  end if;

  if p_role not in ('admin', 'manager', 'operator', 'viewer') then
    raise exception 'Invalid role';
  end if;

  select role, active
    into v_target_role, v_target_active
  from public.users
  where id = p_target_user_id;

  if v_target_role is null then
    raise exception 'User not found';
  end if;

  if v_target_role = 'admin' and p_role <> 'admin' and coalesce(v_target_active, false) is true then
    select count(*)::bigint
      into v_active_admin_count
    from public.users
    where role = 'admin'
      and active = true;

    if v_active_admin_count <= 1 then
      raise exception 'Last active admin cannot be demoted';
    end if;
  end if;

  update public.users
  set role = p_role
  where id = p_target_user_id
  returning id into v_user_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'users.role_change',
    p_actor_id,
    v_user_id::text,
    'user',
    jsonb_build_object('role', p_role),
    now()
  );

  return query select v_user_id;
end;
$$;

create or replace function public.admin_set_user_active_with_audit_atomic(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_active boolean
)
returns table (user_id uuid)
language plpgsql
security invoker
as $$
declare
  v_actor_role text;
  v_actor_active boolean;
  v_target_role text;
  v_target_active boolean;
  v_active_admin_count bigint;
  v_user_id uuid;
begin
  select role, active
    into v_actor_role, v_actor_active
  from public.users
  where id = p_actor_id;

  if coalesce(v_actor_active, false) is not true or v_actor_role <> 'admin' then
    raise exception 'Only active admin can perform this action';
  end if;

  if p_target_user_id = p_actor_id and p_active is false then
    raise exception 'Cannot disable self';
  end if;

  select role, active
    into v_target_role, v_target_active
  from public.users
  where id = p_target_user_id;

  if v_target_role is null then
    raise exception 'User not found';
  end if;

  if v_target_role = 'admin' and coalesce(v_target_active, false) is true and p_active is false then
    select count(*)::bigint
      into v_active_admin_count
    from public.users
    where role = 'admin'
      and active = true;

    if v_active_admin_count <= 1 then
      raise exception 'Last active admin cannot be disabled';
    end if;
  end if;

  update public.users
  set active = p_active
  where id = p_target_user_id
  returning id into v_user_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    case when p_active then 'users.enable' else 'users.disable' end,
    p_actor_id,
    v_user_id::text,
    'user',
    jsonb_build_object('active', p_active),
    now()
  );

  return query select v_user_id;
end;
$$;
