# Role-Based Access

Default role comes from `APP_DEFAULT_ROLE` (fallback: `admin`).

## Roles
- `admin`
- `sales`
- `finance`
- `hr`

## Usage
Controllers should call `require_role!`:

```
require_role!(Roles::ADMIN, Roles::SALES)
```

## Supabase Auth Integration
- Login uses Supabase Auth (`/auth/v1/token?grant_type=password`).
- Session stores `access_token` and `refresh_token`.
- `Current.user` is built by:
  1) Fetching Supabase auth user from `access_token`
  2) Loading role from `users` table

## Required `users` Table (Supabase SQL)
```
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'admin',
  active boolean not null default true
);
```
