-- ==============================================================================
-- KANAVU ILLAM - SECURE DATABASE SCHEMA WITH ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- 1. Enable UUID Extension
create extension if not exists "uuid-ossp";

-- 2. Projects Table
create table if not exists projects (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  user_email text,
  name text not null,
  image_url text,
  model_data jsonb not null default '{}',
  vastu_data jsonb,
  cost_data jsonb,
  elevation_data jsonb,
  structural_data jsonb,
  visual_data jsonb,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 3. Add any missing columns to existing table if already created
alter table projects add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table projects add column if not exists user_email text;
alter table projects add column if not exists vastu_data jsonb;
alter table projects add column if not exists cost_data jsonb;
alter table projects add column if not exists elevation_data jsonb;
alter table projects add column if not exists structural_data jsonb;
alter table projects add column if not exists visual_data jsonb;
alter table projects add column if not exists updated_at timestamp with time zone default now();

-- 4. High-Performance Query Indexes
create index if not exists idx_projects_user_id on projects (user_id);
create index if not exists idx_projects_user_email on projects (user_email);
create index if not exists idx_projects_created_at on projects (created_at desc);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- 5. Enable Row Level Security
alter table projects enable row level security;

-- 6. DROP the insecure prototype policy and old policies
drop policy if exists "Public Access" on projects;
drop policy if exists "Users can view own projects" on projects;
drop policy if exists "Users can insert own projects" on projects;
drop policy if exists "Users can update own projects" on projects;
drop policy if exists "Users can delete own projects" on projects;
drop policy if exists "Service role has full access" on projects;

-- 7. Policy: Service Role (Backend Node.js server) full access
-- Supabase automatically bypasses RLS for service_role, but this policy guarantees explicit permission
create policy "Service role has full access" on projects
  for all
  to service_role
  using (true)
  with check (true);

-- 8. Policy: Authenticated users can SELECT only their own projects
create policy "Users can view own projects" on projects
  for select
  to authenticated
  using (
    auth.uid() = user_id 
    or (auth.jwt() ->> 'email') = user_email
  );

-- 9. Policy: Authenticated users can INSERT only for themselves
create policy "Users can insert own projects" on projects
  for insert
  to authenticated
  with check (
    auth.uid() = user_id 
    or (auth.jwt() ->> 'email') = user_email
  );

-- 10. Policy: Authenticated users can UPDATE only their own projects
create policy "Users can update own projects" on projects
  for update
  to authenticated
  using (
    auth.uid() = user_id 
    or (auth.jwt() ->> 'email') = user_email
  )
  with check (
    auth.uid() = user_id 
    or (auth.jwt() ->> 'email') = user_email
  );

-- 11. Policy: Authenticated users can DELETE only their own projects
create policy "Users can delete own projects" on projects
  for delete
  to authenticated
  using (
    auth.uid() = user_id 
    or (auth.jwt() ->> 'email') = user_email
  );

-- ==============================================================================
-- 12. PAYMENTS & TRANSACTIONS TABLE
-- ==============================================================================

create table if not exists payments (
  id uuid default uuid_generate_v4() primary key,
  order_id text not null unique,
  payment_id text,
  user_id uuid references auth.users(id) on delete set null,
  user_email text,
  project_id uuid references projects(id) on delete set null,
  amount numeric(10, 2) not null default 500.00,
  currency text not null default 'INR',
  status text not null default 'pending', -- 'pending', 'paid', 'failed'
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create index if not exists idx_payments_order_id on payments (order_id);
create index if not exists idx_payments_user_id on payments (user_id);
create index if not exists idx_payments_user_email on payments (user_email);
create index if not exists idx_payments_status on payments (status);

alter table payments enable row level security;

create policy "Service role has full access to payments" on payments
  for all
  to service_role
  using (true)
  with check (true);

create policy "Users can view own payments" on payments
  for select
  to authenticated
  using (
    auth.uid() = user_id 
    or (auth.jwt() ->> 'email') = user_email
  );

