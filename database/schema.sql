-- Projects Table (updated schema with pipeline columns)
create table if not exists projects (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  image_url text,
  model_data jsonb not null default '{}',
  vastu_data jsonb,
  cost_data jsonb,
  elevation_data jsonb,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table projects enable row level security;

-- Policy to allow anonymous usage for prototype
create policy "Public Access" on projects
  for all using (true) with check (true);

-- Add new columns to existing table (run this if table already exists)
alter table projects add column if not exists vastu_data jsonb;
alter table projects add column if not exists cost_data jsonb;
alter table projects add column if not exists elevation_data jsonb;
