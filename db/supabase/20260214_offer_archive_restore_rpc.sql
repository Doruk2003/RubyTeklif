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
    and deleted_at is null
  returning id into v_offer_id;

  if v_offer_id is null then
    raise exception 'Offer not found or not allowed';
  end if;

  update public.offer_items
  set deleted_at = now()
  where offer_id = v_offer_id
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
    and deleted_at is not null
  returning id into v_offer_id;

  if v_offer_id is null then
    raise exception 'Offer not found or not allowed';
  end if;

  update public.offer_items
  set deleted_at = null
  where offer_id = v_offer_id
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
