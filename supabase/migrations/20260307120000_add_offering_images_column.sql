alter table public.offerings
add column if not exists images text[] default '{}'::text[];
