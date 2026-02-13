-- Referential integrity and index audit report (read-only)
with expected_relations as (
  select * from (
    values
      ('companies', 'user_id', 'users', 'id', 'companies_user_id_fkey'),
      ('categories', 'user_id', 'users', 'id', 'categories_user_id_fkey'),
      ('products', 'user_id', 'users', 'id', 'products_user_id_fkey'),
      ('products', 'category_id', 'categories', 'id', 'products_category_id_fkey'),
      ('offers', 'user_id', 'users', 'id', 'offers_user_id_fkey'),
      ('offers', 'company_id', 'companies', 'id', 'offers_company_id_fkey'),
      ('offer_items', 'user_id', 'users', 'id', 'offer_items_user_id_fkey'),
      ('offer_items', 'offer_id', 'offers', 'id', 'offer_items_offer_id_fkey'),
      ('offer_items', 'product_id', 'products', 'id', 'offer_items_product_id_fkey'),
      ('currencies', 'user_id', 'users', 'id', 'currencies_user_id_fkey'),
      ('activity_logs', 'actor_id', 'users', 'id', 'activity_logs_actor_id_fkey')
  ) as t(table_name, column_name, ref_table, ref_column, expected_constraint_name)
),
fk_state as (
  select
    e.table_name,
    e.column_name,
    e.ref_table,
    e.ref_column,
    e.expected_constraint_name,
    exists (
      select 1
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = e.table_name
        and c.contype = 'f'
        and c.conname = e.expected_constraint_name
    ) as fk_exists
  from expected_relations e
),
not_null_state as (
  select
    e.table_name,
    e.column_name,
    c.is_nullable = 'NO' as is_not_null
  from expected_relations e
  join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = e.table_name
   and c.column_name = e.column_name
),
index_state as (
  select
    e.table_name,
    e.column_name,
    exists (
      select 1
      from pg_index i
      join pg_class t on t.oid = i.indrelid
      join pg_namespace n on n.oid = t.relnamespace
      join pg_attribute a on a.attrelid = t.oid and a.attnum = any(i.indkey)
      where n.nspname = 'public'
        and t.relname = e.table_name
        and a.attname = e.column_name
    ) as has_index
  from expected_relations e
)
select
  f.table_name,
  f.column_name,
  f.ref_table,
  f.ref_column,
  f.fk_exists,
  nn.is_not_null,
  ix.has_index
from fk_state f
join not_null_state nn using (table_name, column_name)
join index_state ix using (table_name, column_name)
order by f.table_name, f.column_name;
