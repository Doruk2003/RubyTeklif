-- Role model v2 compatibility refresh.
-- New roles: admin, manager, operator, viewer
-- Legacy roles preserved during transition: sales, finance, hr

create or replace function public.has_role(role_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.active = true
      and u.role = role_name
  );
$$;

create or replace function public.has_any_role(role_names text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.active = true
      and u.role = any(role_names)
  );
$$;

-- users table policies
drop policy if exists users_select_self on public.users;
create policy users_select_self
on public.users for select
using (id = auth.uid());

drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users for update
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists users_admin_read_all on public.users;
create policy users_admin_read_all
on public.users for select
using (public.has_role('admin'));

drop policy if exists users_admin_update_all on public.users;
create policy users_admin_update_all
on public.users for update
using (public.has_role('admin'))
with check (true);

-- activity_logs table policies
drop policy if exists activity_logs_admin_read on public.activity_logs;
create policy activity_logs_admin_read
on public.activity_logs for select
using (public.has_role('admin'));

drop policy if exists activity_logs_insert_actor on public.activity_logs;
create policy activity_logs_insert_actor
on public.activity_logs for insert
with check (
  actor_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales', 'finance', 'hr'])
);

-- companies table policies
drop policy if exists companies_owner_read on public.companies;
create policy companies_owner_read
on public.companies for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists companies_owner_insert on public.companies;
create policy companies_owner_insert
on public.companies for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists companies_owner_update on public.companies;
create policy companies_owner_update
on public.companies for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists companies_owner_delete on public.companies;
create policy companies_owner_delete
on public.companies for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

-- categories table policies
drop policy if exists categories_owner_read on public.categories;
create policy categories_owner_read
on public.categories for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists categories_owner_insert on public.categories;
create policy categories_owner_insert
on public.categories for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists categories_owner_update on public.categories;
create policy categories_owner_update
on public.categories for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists categories_owner_delete on public.categories;
create policy categories_owner_delete
on public.categories for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

-- products table policies
drop policy if exists products_owner_read on public.products;
create policy products_owner_read
on public.products for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists products_owner_insert on public.products;
create policy products_owner_insert
on public.products for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists products_owner_update on public.products;
create policy products_owner_update
on public.products for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists products_owner_delete on public.products;
create policy products_owner_delete
on public.products for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

-- currencies table policies
drop policy if exists currencies_owner_read on public.currencies;
create policy currencies_owner_read
on public.currencies for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'finance'])
);

drop policy if exists currencies_owner_insert on public.currencies;
create policy currencies_owner_insert
on public.currencies for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'finance'])
);

drop policy if exists currencies_owner_update on public.currencies;
create policy currencies_owner_update
on public.currencies for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'finance'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'finance'])
);

drop policy if exists currencies_owner_delete on public.currencies;
create policy currencies_owner_delete
on public.currencies for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'finance'])
);

-- offers table policies
drop policy if exists offers_owner_read on public.offers;
create policy offers_owner_read
on public.offers for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists offers_owner_insert on public.offers;
create policy offers_owner_insert
on public.offers for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists offers_owner_update on public.offers;
create policy offers_owner_update
on public.offers for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists offers_owner_delete on public.offers;
create policy offers_owner_delete
on public.offers for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

-- offer_items table policies
drop policy if exists offer_items_owner_read on public.offer_items;
create policy offer_items_owner_read
on public.offer_items for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists offer_items_owner_insert on public.offer_items;
create policy offer_items_owner_insert
on public.offer_items for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists offer_items_owner_update on public.offer_items;
create policy offer_items_owner_update
on public.offer_items for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists offer_items_owner_delete on public.offer_items;
create policy offer_items_owner_delete
on public.offer_items for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);
