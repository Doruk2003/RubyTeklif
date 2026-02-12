# Supabase Users Auto-Insert

This keeps `public.users` in sync with `auth.users`.

## SQL (run in Supabase SQL editor)

```
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'admin',
  active boolean not null default true
);

create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.users (id, email, role)
  values (new.id, new.email, 'admin')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_auth_user_created();
```

## Notes
- Change default role if needed.
- `security definer` ensures trigger can write to public schema.
