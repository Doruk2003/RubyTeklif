


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."admin_set_user_active_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_active" boolean) RETURNS TABLE("user_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."admin_set_user_active_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_update_user_role_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_role" "text") RETURNS TABLE("user_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."admin_update_user_role_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") RETURNS TABLE("category_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."archive_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") RETURNS TABLE("company_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."archive_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") RETURNS TABLE("currency_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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



ALTER FUNCTION "public"."archive_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") RETURNS TABLE("offer_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."archive_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") RETURNS TABLE("product_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."archive_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_brand_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) RETURNS TABLE("brand_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
declare
  v_brand_id uuid;
begin
  insert into public.brands (
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
  returning id into v_brand_id;

  insert into public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  values (
    'brands.create',
    p_actor_id,
    v_brand_id::text,
    'brand',
    jsonb_build_object('code', p_code, 'name', p_name),
    now()
  );

  return query select v_brand_id;
end;
$$;


ALTER FUNCTION "public"."create_brand_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_category_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) RETURNS TABLE("category_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."create_category_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_company_with_audit_atomic"("p_actor_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) RETURNS TABLE("company_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."create_company_with_audit_atomic"("p_actor_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_currency_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) RETURNS TABLE("currency_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."create_currency_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_offer_with_items_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_offer_number" "text", "p_offer_date" "date", "p_status" "text", "p_net_total" numeric, "p_vat_total" numeric, "p_gross_total" numeric, "p_items" "jsonb") RETURNS TABLE("offer_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."create_offer_with_items_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_offer_number" "text", "p_offer_date" "date", "p_status" "text", "p_net_total" numeric, "p_vat_total" numeric, "p_gross_total" numeric, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_product_with_audit_atomic"("p_actor_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) RETURNS TABLE("product_id" "uuid")
    LANGUAGE "plpgsql"
    AS $_$
declare
  v_product_id uuid;
  v_brand_ok boolean;
  v_currency_ok boolean;
  v_sku text;
  v_category_code text;
  v_prefix text;
  v_next_number integer;
  v_description text;
  v_barcode text;
begin
  select c.code
    into v_category_code
  from public.categories c
  where c.id = p_category_id
    and c.user_id = p_actor_id
    and c.deleted_at is null;

  if v_category_code is null then
    raise exception 'Category not found or not allowed';
  end if;

  if p_brand_id is not null then
    select exists (
      select 1
      from public.brands b
      where b.id = p_brand_id
        and b.user_id = p_actor_id
        and b.deleted_at is null
    ) into v_brand_ok;

    if coalesce(v_brand_ok, false) is not true then
      raise exception 'Brand not found or not allowed';
    end if;
  end if;

  if p_currency_id is not null then
    select exists (
      select 1
      from public.currencies cur
      where cur.id = p_currency_id
        and cur.user_id = p_actor_id
        and cur.deleted_at is null
    ) into v_currency_ok;

    if coalesce(v_currency_ok, false) is not true then
      raise exception 'Currency not found or not allowed';
    end if;
  end if;

  if nullif(btrim(p_sku), '') is null then
    v_prefix := left(
      upper(regexp_replace(coalesce(v_category_code, ''), '[^A-Za-z0-9]', '', 'g')) || 'XXX',
      3
    );

    select coalesce(max((substring(upper(sku) from '([0-9]{5})$'))::integer), 0) + 1
      into v_next_number
    from public.products
    where user_id = p_actor_id
      and upper(sku) ~ ('^' || v_prefix || '-[0-9]{5}$');

    v_sku := v_prefix || '-' || lpad(v_next_number::text, 5, '0');
  else
    v_sku := upper(btrim(p_sku));
  end if;

  v_description := nullif(btrim(coalesce(p_description, '')), '');
  v_barcode := nullif(upper(btrim(coalesce(p_barcode, ''))), '');

  insert into public.products (
    user_id,
    sku,
    name,
    description,
    barcode,
    price,
    cost_price,
    stock_quantity,
    min_stock_level,
    vat_rate,
    item_type,
    category_id,
    brand_id,
    currency_id,
    unit,
    is_stock_item,
    sale_price_vat_included,
    cost_price_vat_included,
    active
  )
  values (
    p_actor_id,
    v_sku,
    p_name,
    v_description,
    v_barcode,
    p_price,
    coalesce(p_cost_price, 0),
    greatest(coalesce(p_stock_quantity, 0), 0),
    greatest(coalesce(p_min_stock_level, 0), 0),
    p_vat_rate,
    p_item_type,
    p_category_id,
    p_brand_id,
    p_currency_id,
    lower(btrim(p_unit)),
    coalesce(p_is_stock_item, true),
    coalesce(p_sale_price_vat_included, false),
    coalesce(p_cost_price_vat_included, false),
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
    jsonb_build_object('sku', v_sku, 'name', p_name, 'barcode', v_barcode),
    now()
  );

  return query select v_product_id;
end;
$_$;


ALTER FUNCTION "public"."create_product_with_audit_atomic"("p_actor_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_auth_user_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.users (id, email, role)
  values (new.id, new.email, 'admin')
  on conflict (id) do nothing;
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_auth_user_created"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_any_role"("role_names" "text"[]) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.active = true
      and u.role = any(role_names)
  );
$$;


ALTER FUNCTION "public"."has_any_role"("role_names" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_role"("role_name" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.active = true
      and u.role = role_name
  );
$$;


ALTER FUNCTION "public"."has_role"("role_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") RETURNS TABLE("category_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."restore_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") RETURNS TABLE("company_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."restore_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") RETURNS TABLE("currency_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."restore_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") RETURNS TABLE("offer_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."restore_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") RETURNS TABLE("product_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."restore_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) RETURNS TABLE("category_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."update_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) RETURNS TABLE("company_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."update_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) RETURNS TABLE("currency_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
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


ALTER FUNCTION "public"."update_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) RETURNS TABLE("product_id" "uuid")
    LANGUAGE "plpgsql"
    AS $_$
declare
  v_product_id uuid;
  v_brand_ok boolean;
  v_currency_ok boolean;
  v_sku text;
  v_category_code text;
  v_prefix text;
  v_next_number integer;
  v_description text;
  v_barcode text;
begin
  select c.code
    into v_category_code
  from public.categories c
  where c.id = p_category_id
    and c.user_id = p_actor_id
    and c.deleted_at is null;

  if v_category_code is null then
    raise exception 'Category not found or not allowed';
  end if;

  if p_brand_id is not null then
    select exists (
      select 1
      from public.brands b
      where b.id = p_brand_id
        and b.user_id = p_actor_id
        and b.deleted_at is null
    ) into v_brand_ok;

    if coalesce(v_brand_ok, false) is not true then
      raise exception 'Brand not found or not allowed';
    end if;
  end if;

  if p_currency_id is not null then
    select exists (
      select 1
      from public.currencies cur
      where cur.id = p_currency_id
        and cur.user_id = p_actor_id
        and cur.deleted_at is null
    ) into v_currency_ok;

    if coalesce(v_currency_ok, false) is not true then
      raise exception 'Currency not found or not allowed';
    end if;
  end if;

  if nullif(btrim(p_sku), '') is null then
    v_prefix := left(
      upper(regexp_replace(coalesce(v_category_code, ''), '[^A-Za-z0-9]', '', 'g')) || 'XXX',
      3
    );

    select coalesce(max((substring(upper(sku) from '([0-9]{5})$'))::integer), 0) + 1
      into v_next_number
    from public.products
    where user_id = p_actor_id
      and id <> p_product_id
      and upper(sku) ~ ('^' || v_prefix || '-[0-9]{5}$');

    v_sku := v_prefix || '-' || lpad(v_next_number::text, 5, '0');
  else
    v_sku := upper(btrim(p_sku));
  end if;

  v_description := nullif(btrim(coalesce(p_description, '')), '');
  v_barcode := nullif(upper(btrim(coalesce(p_barcode, ''))), '');

  update public.products
  set
    sku = v_sku,
    name = p_name,
    description = v_description,
    barcode = v_barcode,
    price = p_price,
    cost_price = coalesce(p_cost_price, 0),
    stock_quantity = greatest(coalesce(p_stock_quantity, 0), 0),
    min_stock_level = greatest(coalesce(p_min_stock_level, 0), 0),
    vat_rate = p_vat_rate,
    item_type = p_item_type,
    category_id = p_category_id,
    brand_id = p_brand_id,
    currency_id = p_currency_id,
    unit = lower(btrim(p_unit)),
    is_stock_item = coalesce(p_is_stock_item, true),
    sale_price_vat_included = coalesce(p_sale_price_vat_included, false),
    cost_price_vat_included = coalesce(p_cost_price_vat_included, false),
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
    jsonb_build_object('sku', v_sku, 'name', p_name, 'barcode', v_barcode),
    now()
  );

  return query select v_product_id;
end;
$_$;


ALTER FUNCTION "public"."update_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activity_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "action" "text" NOT NULL,
    "actor_id" "uuid" NOT NULL,
    "target_id" "text" NOT NULL,
    "target_type" "text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."activity_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."brands" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."brands" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."calendar_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "event_date" "date" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "color" "text" DEFAULT '#38bdf8'::"text" NOT NULL,
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "start_at" timestamp with time zone NOT NULL,
    "remind_minutes_before" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "calendar_events_color_hex" CHECK (("color" ~ '^#[0-9A-Fa-f]{6}$'::"text")),
    CONSTRAINT "calendar_events_description_length" CHECK ((("description" IS NULL) OR ("char_length"("description") <= 1000))),
    CONSTRAINT "calendar_events_remind_minutes_before_range" CHECK ((("remind_minutes_before" >= 0) AND ("remind_minutes_before" <= 1440))),
    CONSTRAINT "calendar_events_title_length" CHECK (("char_length"("title") <= 160)),
    CONSTRAINT "calendar_events_title_presence" CHECK (("char_length"("btrim"("title")) > 0))
);


ALTER TABLE "public"."calendar_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."companies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "tax_number" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "authorized_person" "text",
    "phone" "text",
    "address" "text",
    "tax_office" "text",
    "active" boolean DEFAULT true NOT NULL,
    "email" "text",
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."companies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."offers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_id" "uuid" NOT NULL,
    "offer_number" "text" NOT NULL,
    "offer_date" "date" NOT NULL,
    "net_total" numeric(10,2) DEFAULT 0 NOT NULL,
    "vat_total" numeric(10,2) DEFAULT 0 NOT NULL,
    "gross_total" numeric(10,2) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'taslak'::"text" NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "offers_status_check" CHECK (("status" = ANY (ARRAY['taslak'::"text", 'gonderildi'::"text", 'beklemede'::"text", 'onaylandi'::"text", 'reddedildi'::"text"])))
);


ALTER TABLE "public"."offers" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."company_offer_stats" WITH ("security_invoker"='true') AS
 SELECT "company_id",
    "count"(*) AS "offers_count"
   FROM "public"."offers" "o"
  WHERE ("deleted_at" IS NULL)
  GROUP BY "company_id";


ALTER VIEW "public"."company_offer_stats" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."company_with_offer_counts" WITH ("security_invoker"='true') AS
 SELECT "c"."id",
    "c"."name",
    "c"."tax_number",
    "c"."tax_office",
    "c"."authorized_person",
    "c"."phone",
    "c"."email",
    "c"."address",
    "c"."active",
    "c"."deleted_at",
    "c"."created_at",
    COALESCE("stats"."offers_count", (0)::bigint) AS "offers_count"
   FROM ("public"."companies" "c"
     LEFT JOIN "public"."company_offer_stats" "stats" ON (("stats"."company_id" = "c"."id")));


ALTER VIEW "public"."company_with_offer_counts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."currencies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "symbol" "text",
    "rate_to_try" numeric(12,6) NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "currencies_rate_to_try_check" CHECK (("rate_to_try" > (0)::numeric))
);


ALTER TABLE "public"."currencies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."offer_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "offer_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "description" "text" NOT NULL,
    "quantity" numeric(10,2) NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "line_total" numeric(12,2) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "discount_rate" numeric(5,2) DEFAULT 0 NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "offer_items_discount_rate_check" CHECK ((("discount_rate" >= (0)::numeric) AND ("discount_rate" <= (100)::numeric))),
    CONSTRAINT "offer_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "offer_items_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."offer_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "file_name" "text",
    "content_type" "text",
    "byte_size" bigint,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."product_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "price" numeric(10,2) NOT NULL,
    "vat_rate" numeric(5,2) NOT NULL,
    "item_type" "text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "category_id" "uuid" NOT NULL,
    "deleted_at" timestamp with time zone,
    "sku" "text" NOT NULL,
    "unit" "text" NOT NULL,
    "brand_id" "uuid",
    "is_stock_item" boolean DEFAULT true NOT NULL,
    "cost_price" numeric DEFAULT 0 NOT NULL,
    "sale_price_vat_included" boolean DEFAULT false NOT NULL,
    "cost_price_vat_included" boolean DEFAULT false NOT NULL,
    "description" "text",
    "barcode" "text",
    "stock_quantity" numeric DEFAULT 0 NOT NULL,
    "min_stock_level" numeric DEFAULT 0 NOT NULL,
    "currency_id" "uuid",
    CONSTRAINT "products_item_type_check" CHECK (("item_type" = ANY (ARRAY['product'::"text", 'demonte'::"text", 'service'::"text"]))),
    CONSTRAINT "products_min_stock_level_nonnegative" CHECK (("min_stock_level" >= (0)::numeric)),
    CONSTRAINT "products_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "products_stock_quantity_nonnegative" CHECK (("stock_quantity" >= (0)::numeric)),
    CONSTRAINT "products_unit_check" CHECK (("unit" = ANY (ARRAY['adet'::"text", 'm'::"text", 'm2'::"text", 'kg'::"text", 'lt'::"text", 'saat'::"text", 'paket'::"text"]))),
    CONSTRAINT "products_vat_rate_check" CHECK (("vat_rate" >= (0)::numeric))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "role" "text" DEFAULT 'admin'::"text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."calendar_events"
    ADD CONSTRAINT "calendar_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."currencies"
    ADD CONSTRAINT "currencies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."offer_items"
    ADD CONSTRAINT "offer_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."offers"
    ADD CONSTRAINT "teklifler_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "activity_logs_action_created_idx" ON "public"."activity_logs" USING "btree" ("action", "created_at" DESC);



CREATE INDEX "activity_logs_actor_id_idx" ON "public"."activity_logs" USING "btree" ("actor_id");



CREATE INDEX "activity_logs_created_idx" ON "public"."activity_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "activity_logs_target_id_created_idx" ON "public"."activity_logs" USING "btree" ("target_id", "created_at" DESC);



CREATE INDEX "activity_logs_target_type_created_idx" ON "public"."activity_logs" USING "btree" ("target_type", "created_at" DESC);



CREATE INDEX "brands_deleted_at_idx" ON "public"."brands" USING "btree" ("deleted_at");



CREATE INDEX "brands_user_active_idx" ON "public"."brands" USING "btree" ("user_id", "active");



CREATE UNIQUE INDEX "brands_user_code_key" ON "public"."brands" USING "btree" ("user_id", "code");



CREATE UNIQUE INDEX "brands_user_name_key" ON "public"."brands" USING "btree" ("user_id", "name");



CREATE INDEX "calendar_events_user_deleted_date_idx" ON "public"."calendar_events" USING "btree" ("user_id", "deleted_at", "event_date", "created_at");



CREATE INDEX "calendar_events_user_deleted_start_at_idx" ON "public"."calendar_events" USING "btree" ("user_id", "deleted_at", "start_at", "created_at");



CREATE INDEX "categories_code_trgm_idx" ON "public"."categories" USING "gin" ("code" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "categories_deleted_at_idx" ON "public"."categories" USING "btree" ("deleted_at");



CREATE INDEX "categories_name_trgm_idx" ON "public"."categories" USING "gin" ("name" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "categories_user_active_idx" ON "public"."categories" USING "btree" ("user_id", "active");



CREATE UNIQUE INDEX "categories_user_code_key" ON "public"."categories" USING "btree" ("user_id", "code") WHERE ("deleted_at" IS NULL);



CREATE INDEX "categories_user_deleted_name_idx" ON "public"."categories" USING "btree" ("user_id", "deleted_at", "name");



CREATE INDEX "categories_user_id_idx" ON "public"."categories" USING "btree" ("user_id");



CREATE UNIQUE INDEX "categories_user_name_key" ON "public"."categories" USING "btree" ("user_id", "name") WHERE ("deleted_at" IS NULL);



CREATE INDEX "companies_active_idx" ON "public"."companies" USING "btree" ("active");



CREATE INDEX "companies_authorized_person_trgm_idx" ON "public"."companies" USING "gin" ("authorized_person" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "companies_deleted_at_idx" ON "public"."companies" USING "btree" ("deleted_at");



CREATE INDEX "companies_email_trgm_idx" ON "public"."companies" USING "gin" ("email" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "companies_name_trgm_idx" ON "public"."companies" USING "gin" ("name" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "companies_phone_trgm_idx" ON "public"."companies" USING "gin" ("phone" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "companies_tax_number_trgm_idx" ON "public"."companies" USING "gin" ("tax_number" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "companies_user_deleted_created_idx" ON "public"."companies" USING "btree" ("user_id", "deleted_at", "created_at" DESC);



CREATE INDEX "companies_user_id_idx" ON "public"."companies" USING "btree" ("user_id");



CREATE UNIQUE INDEX "companies_user_tax_number_idx" ON "public"."companies" USING "btree" ("user_id", "tax_number") WHERE (("deleted_at" IS NULL) AND ("tax_number" IS NOT NULL));



CREATE INDEX "currencies_active_idx" ON "public"."currencies" USING "btree" ("active");



CREATE INDEX "currencies_deleted_at_idx" ON "public"."currencies" USING "btree" ("deleted_at");



CREATE UNIQUE INDEX "currencies_user_code_idx" ON "public"."currencies" USING "btree" ("user_id", "code");



CREATE UNIQUE INDEX "currencies_user_code_unique_idx" ON "public"."currencies" USING "btree" ("user_id", "upper"("code")) WHERE (("deleted_at" IS NULL) AND ("code" IS NOT NULL) AND ("btrim"("code") <> ''::"text"));



CREATE INDEX "currencies_user_deleted_code_idx" ON "public"."currencies" USING "btree" ("user_id", "deleted_at", "code");



CREATE INDEX "currencies_user_id_idx" ON "public"."currencies" USING "btree" ("user_id");



CREATE INDEX "offer_items_deleted_at_idx" ON "public"."offer_items" USING "btree" ("deleted_at");



CREATE INDEX "offer_items_offer_id_idx" ON "public"."offer_items" USING "btree" ("offer_id");



CREATE INDEX "offer_items_product_id_idx" ON "public"."offer_items" USING "btree" ("product_id");



CREATE INDEX "offer_items_user_id_idx" ON "public"."offer_items" USING "btree" ("user_id");



CREATE INDEX "offers_company_id_idx" ON "public"."offers" USING "btree" ("company_id");



CREATE INDEX "offers_deleted_at_idx" ON "public"."offers" USING "btree" ("deleted_at");



CREATE INDEX "offers_user_deleted_offer_date_idx" ON "public"."offers" USING "btree" ("user_id", "deleted_at", "offer_date" DESC, "created_at" DESC);



CREATE INDEX "offers_user_id_idx" ON "public"."offers" USING "btree" ("user_id");



CREATE UNIQUE INDEX "offers_user_offer_number_unique_idx" ON "public"."offers" USING "btree" ("user_id", "offer_number") WHERE (("deleted_at" IS NULL) AND ("offer_number" IS NOT NULL) AND ("btrim"("offer_number") <> ''::"text"));



CREATE INDEX "product_images_deleted_at_idx" ON "public"."product_images" USING "btree" ("deleted_at");



CREATE INDEX "product_images_product_id_idx" ON "public"."product_images" USING "btree" ("product_id");



CREATE INDEX "product_images_sort_idx" ON "public"."product_images" USING "btree" ("product_id", "sort_order");



CREATE INDEX "product_images_user_id_idx" ON "public"."product_images" USING "btree" ("user_id");



CREATE INDEX "products_active_idx" ON "public"."products" USING "btree" ("active");



CREATE INDEX "products_barcode_trgm_idx" ON "public"."products" USING "gin" ("barcode" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "products_brand_id_idx" ON "public"."products" USING "btree" ("brand_id");



CREATE INDEX "products_category_id_idx" ON "public"."products" USING "btree" ("category_id");



CREATE INDEX "products_company_id_idx" ON "public"."products" USING "btree" ("company_id");



CREATE INDEX "products_currency_id_idx" ON "public"."products" USING "btree" ("currency_id");



CREATE INDEX "products_deleted_at_idx" ON "public"."products" USING "btree" ("deleted_at");



CREATE INDEX "products_name_trgm_idx" ON "public"."products" USING "gin" ("name" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE INDEX "products_sku_trgm_idx" ON "public"."products" USING "gin" ("sku" "public"."gin_trgm_ops") WHERE ("deleted_at" IS NULL);



CREATE UNIQUE INDEX "products_user_barcode_key" ON "public"."products" USING "btree" ("user_id", "upper"("barcode")) WHERE (("barcode" IS NOT NULL) AND ("btrim"("barcode") <> ''::"text"));



CREATE INDEX "products_user_deleted_created_idx" ON "public"."products" USING "btree" ("user_id", "deleted_at", "created_at" DESC);



CREATE INDEX "products_user_id_idx" ON "public"."products" USING "btree" ("user_id");



CREATE UNIQUE INDEX "products_user_sku_key" ON "public"."products" USING "btree" ("user_id", "upper"("sku"));



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."calendar_events"
    ADD CONSTRAINT "calendar_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."currencies"
    ADD CONSTRAINT "currencies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."offer_items"
    ADD CONSTRAINT "offer_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "public"."offers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."offer_items"
    ADD CONSTRAINT "offer_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."offer_items"
    ADD CONSTRAINT "offer_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."offers"
    ADD CONSTRAINT "offers_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."offers"
    ADD CONSTRAINT "offers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "public"."brands"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_currency_id_fkey" FOREIGN KEY ("currency_id") REFERENCES "public"."currencies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."offers"
    ADD CONSTRAINT "teklifler_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."offers"
    ADD CONSTRAINT "teklifler_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE "public"."activity_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_logs_admin_read" ON "public"."activity_logs" FOR SELECT USING ("public"."has_role"('admin'::"text"));



CREATE POLICY "activity_logs_insert_actor" ON "public"."activity_logs" FOR INSERT WITH CHECK ((("actor_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text", 'finance'::"text", 'hr'::"text"])));



ALTER TABLE "public"."brands" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "brands_owner_delete" ON "public"."brands" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



CREATE POLICY "brands_owner_insert" ON "public"."brands" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



CREATE POLICY "brands_owner_read" ON "public"."brands" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



CREATE POLICY "brands_owner_update" ON "public"."brands" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"]))))))) WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



ALTER TABLE "public"."calendar_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "calendar_events_owner_delete" ON "public"."calendar_events" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "calendar_events_owner_insert" ON "public"."calendar_events" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "calendar_events_owner_read" ON "public"."calendar_events" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'viewer'::"text", 'sales'::"text", 'finance'::"text", 'hr'::"text"])));



CREATE POLICY "calendar_events_owner_update" ON "public"."calendar_events" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_owner_delete" ON "public"."categories" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "categories_owner_insert" ON "public"."categories" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "categories_owner_read" ON "public"."categories" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "categories_owner_update" ON "public"."categories" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



ALTER TABLE "public"."companies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "companies_delete_own" ON "public"."companies" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "companies_insert_own" ON "public"."companies" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "companies_owner_delete" ON "public"."companies" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "companies_owner_insert" ON "public"."companies" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "companies_owner_read" ON "public"."companies" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "companies_owner_update" ON "public"."companies" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "companies_select_own" ON "public"."companies" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "companies_update_own" ON "public"."companies" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."currencies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "currencies_delete_own" ON "public"."currencies" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "currencies_insert_own" ON "public"."currencies" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "currencies_owner_delete" ON "public"."currencies" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'finance'::"text"])));



CREATE POLICY "currencies_owner_insert" ON "public"."currencies" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'finance'::"text"])));



CREATE POLICY "currencies_owner_read" ON "public"."currencies" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'finance'::"text"])));



CREATE POLICY "currencies_owner_update" ON "public"."currencies" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'finance'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'finance'::"text"])));



CREATE POLICY "currencies_select_own" ON "public"."currencies" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "currencies_update_own" ON "public"."currencies" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."offer_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "offer_items_delete_own" ON "public"."offer_items" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "offer_items_insert_own" ON "public"."offer_items" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "offer_items_owner_delete" ON "public"."offer_items" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offer_items_owner_insert" ON "public"."offer_items" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offer_items_owner_read" ON "public"."offer_items" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offer_items_owner_update" ON "public"."offer_items" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offer_items_select_own" ON "public"."offer_items" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "offer_items_update_own" ON "public"."offer_items" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."offers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "offers_delete_own" ON "public"."offers" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "offers_insert_own" ON "public"."offers" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "offers_owner_delete" ON "public"."offers" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offers_owner_insert" ON "public"."offers" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offers_owner_read" ON "public"."offers" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offers_owner_update" ON "public"."offers" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "offers_select_own" ON "public"."offers" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "offers_update_own" ON "public"."offers" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."product_images" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "product_images_owner_delete" ON "public"."product_images" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



CREATE POLICY "product_images_owner_insert" ON "public"."product_images" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



CREATE POLICY "product_images_owner_read" ON "public"."product_images" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



CREATE POLICY "product_images_owner_update" ON "public"."product_images" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"]))))))) WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = ANY (ARRAY['admin'::"text", 'sales'::"text"])))))));



ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_delete_own" ON "public"."products" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "products_insert_own" ON "public"."products" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "products_owner_delete" ON "public"."products" FOR DELETE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "products_owner_insert" ON "public"."products" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "products_owner_read" ON "public"."products" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "products_owner_update" ON "public"."products" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"]))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."has_any_role"(ARRAY['admin'::"text", 'manager'::"text", 'operator'::"text", 'sales'::"text"])));



CREATE POLICY "products_select_own" ON "public"."products" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "products_update_own" ON "public"."products" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_admin_read_all" ON "public"."users" FOR SELECT USING ("public"."has_role"('admin'::"text"));



CREATE POLICY "users_admin_update_all" ON "public"."users" FOR UPDATE USING ("public"."has_role"('admin'::"text")) WITH CHECK (true);



CREATE POLICY "users_select_self" ON "public"."users" FOR SELECT USING (("id" = "auth"."uid"()));



CREATE POLICY "users_update_self" ON "public"."users" FOR UPDATE USING (("id" = "auth"."uid"())) WITH CHECK (("id" = "auth"."uid"()));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_set_user_active_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_user_active_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_user_active_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_update_user_role_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_update_user_role_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_update_user_role_with_audit_atomic"("p_actor_id" "uuid", "p_target_user_id" "uuid", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."archive_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."archive_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."archive_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."archive_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."archive_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_brand_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_brand_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_brand_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_category_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_category_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_category_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_company_with_audit_atomic"("p_actor_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_company_with_audit_atomic"("p_actor_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_company_with_audit_atomic"("p_actor_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_currency_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_currency_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_currency_with_audit_atomic"("p_actor_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_offer_with_items_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_offer_number" "text", "p_offer_date" "date", "p_status" "text", "p_net_total" numeric, "p_vat_total" numeric, "p_gross_total" numeric, "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_offer_with_items_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_offer_number" "text", "p_offer_date" "date", "p_status" "text", "p_net_total" numeric, "p_vat_total" numeric, "p_gross_total" numeric, "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_offer_with_items_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_offer_number" "text", "p_offer_date" "date", "p_status" "text", "p_net_total" numeric, "p_vat_total" numeric, "p_gross_total" numeric, "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_product_with_audit_atomic"("p_actor_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."create_product_with_audit_atomic"("p_actor_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_product_with_audit_atomic"("p_actor_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "service_role";



GRANT ALL ON FUNCTION "public"."has_any_role"("role_names" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."has_any_role"("role_names" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_any_role"("role_names" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."has_role"("role_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."has_role"("role_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_role"("role_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."restore_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."restore_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."restore_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."restore_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_offer_with_items_and_audit_atomic"("p_actor_id" "uuid", "p_offer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."restore_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_category_with_audit_atomic"("p_actor_id" "uuid", "p_category_id" "uuid", "p_code" "text", "p_name" "text", "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_company_with_audit_atomic"("p_actor_id" "uuid", "p_company_id" "uuid", "p_name" "text", "p_tax_number" "text", "p_tax_office" "text", "p_authorized_person" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_currency_with_audit_atomic"("p_actor_id" "uuid", "p_currency_id" "uuid", "p_code" "text", "p_name" "text", "p_symbol" "text", "p_rate_to_try" numeric, "p_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_product_with_audit_atomic"("p_actor_id" "uuid", "p_product_id" "uuid", "p_sku" "text", "p_name" "text", "p_description" "text", "p_barcode" "text", "p_price" numeric, "p_cost_price" numeric, "p_stock_quantity" numeric, "p_min_stock_level" numeric, "p_vat_rate" numeric, "p_item_type" "text", "p_category_id" "uuid", "p_brand_id" "uuid", "p_currency_id" "uuid", "p_unit" "text", "p_is_stock_item" boolean, "p_sale_price_vat_included" boolean, "p_cost_price_vat_included" boolean, "p_active" boolean) TO "service_role";



GRANT ALL ON TABLE "public"."activity_logs" TO "anon";
GRANT ALL ON TABLE "public"."activity_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_logs" TO "service_role";



GRANT ALL ON TABLE "public"."brands" TO "anon";
GRANT ALL ON TABLE "public"."brands" TO "authenticated";
GRANT ALL ON TABLE "public"."brands" TO "service_role";



GRANT ALL ON TABLE "public"."calendar_events" TO "anon";
GRANT ALL ON TABLE "public"."calendar_events" TO "authenticated";
GRANT ALL ON TABLE "public"."calendar_events" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."companies" TO "anon";
GRANT ALL ON TABLE "public"."companies" TO "authenticated";
GRANT ALL ON TABLE "public"."companies" TO "service_role";



GRANT ALL ON TABLE "public"."offers" TO "anon";
GRANT ALL ON TABLE "public"."offers" TO "authenticated";
GRANT ALL ON TABLE "public"."offers" TO "service_role";



GRANT ALL ON TABLE "public"."company_offer_stats" TO "anon";
GRANT ALL ON TABLE "public"."company_offer_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."company_offer_stats" TO "service_role";



GRANT ALL ON TABLE "public"."company_with_offer_counts" TO "anon";
GRANT ALL ON TABLE "public"."company_with_offer_counts" TO "authenticated";
GRANT ALL ON TABLE "public"."company_with_offer_counts" TO "service_role";



GRANT ALL ON TABLE "public"."currencies" TO "anon";
GRANT ALL ON TABLE "public"."currencies" TO "authenticated";
GRANT ALL ON TABLE "public"."currencies" TO "service_role";



GRANT ALL ON TABLE "public"."offer_items" TO "anon";
GRANT ALL ON TABLE "public"."offer_items" TO "authenticated";
GRANT ALL ON TABLE "public"."offer_items" TO "service_role";



GRANT ALL ON TABLE "public"."product_images" TO "anon";
GRANT ALL ON TABLE "public"."product_images" TO "authenticated";
GRANT ALL ON TABLE "public"."product_images" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";









