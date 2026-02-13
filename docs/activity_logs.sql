create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  actor_id uuid references auth.users(id) on delete set null,
  target_id text not null,
  target_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
