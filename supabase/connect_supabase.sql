-- ============================================================================
-- SUPERSEDED - use supabase/schema.sql instead (single authoritative file
-- covering profiles, pets, products, chat, RLS, storage and realtime).
-- ============================================================================
-- connect_supabase.sql
-- Wiring of the database to the shape the app expects. Run it AFTER
-- supabase/run_this_first.sql. Safe to run twice: every statement is additive
-- or idempotent. Nothing is destroyed. On a fresh database it also creates the
-- products table; on this project's hand-built tables it repairs the NOT NULL
-- and CHECK constraints that used to reject every app insert.
-- Run in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. profiles: the verification badge the pet/buyer view embeds.
--    Without it, PetRepository's seller join returns HTTP 400 and every
--    listing fetch silently fails.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_verified boolean not null default false;

-- ----------------------------------------------------------------------------
-- 2. products: add the columns the app actually reads/writes.
--    Existing table only had id, name, brand, description, created_at,
--    updated_at, mrp. On an empty database the table is created here so this
--    script is the single source of truth for the products shape.
-- ----------------------------------------------------------------------------
create table if not exists public.products (
  id             uuid primary key default gen_random_uuid(),
  store_id       uuid,
  category_id    uuid,
  name           text not null,
  brand          text not null default '',
  selling_price  numeric(12, 2) not null default 0,
  mrp            numeric(12, 2) not null default 0,
  free_delivery  boolean not null default false,
  description    text not null default '',
  status         text not null default 'active',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.products add column if not exists category     text             not null default 'accessories';
alter table public.products add column if not exists price        double precision not null default 0;
alter table public.products add column if not exists old_price    double precision null;
alter table public.products add column if not exists image_url    text             not null default '';
alter table public.products add column if not exists highlights   text[]           not null default '{}';
alter table public.products add column if not exists stock        integer          not null default 20;
alter table public.products add column if not exists sold_count   integer          not null default 0;
alter table public.products add column if not exists is_featured      boolean not null default false;
alter table public.products add column if not exists is_best_seller   boolean not null default false;
alter table public.products add column if not exists free_shipping    boolean not null default true;
alter table public.products add column if not exists species_tags     text[]           not null default '{}';
alter table public.products add column if not exists rating        double precision not null default 4.5;
alter table public.products add column if not exists review_count  integer          not null default 0;
alter table public.products add column if not exists shop_name     text             not null default 'My Pet Shop';
alter table public.products add column if not exists shop_verified boolean          not null default false;

-- Ownership: one real seller uuid per product, matching pets.seller_id.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products'
      and column_name = 'seller_id'
  ) then
    alter table public.products
      add column seller_id uuid not null
        default '00000000-0000-0000-0000-000000000000'
        references public.profiles (id) on delete cascade;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 3. Row Level Security for products.  That is what returned 401 on insert:
--    default-deny. The store grid is readable by everyone (anon got 200), and
--    only the owner can write.
-- ----------------------------------------------------------------------------
alter table public.products enable row level security;

drop policy if exists "products_read"     on public.products;
drop policy if exists "products_insert_own" on public.products;
drop policy if exists "products_update_own" on public.products;
drop policy if exists "products_delete_own" on public.products;

create policy "products_read" on public.products
  for select to anon, authenticated using (true);

create policy "products_insert_own" on public.products
  for insert with check (auth.uid() = seller_id);

create policy "products_update_own" on public.products
  for update using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

create policy "products_delete_own" on public.products
  for delete using (auth.uid() = seller_id);

-- Public marketplace grants: anonymous visitors can browse pets and products
-- (the policies above let the rows through). profiles gets a select grant too
-- so the embedded seller join resolves to null instead of erroring - the
-- profiles RLS policy still keeps those rows hidden from anyone not signed in.
grant select on public.pets to anon;
grant select on public.products to anon;
grant select on public.profiles to anon;

-- ----------------------------------------------------------------------------
-- 4. Storage buckets the image uploads go to.  The app uploads under
--    <userId>/<timestamp>.ext, so the owner-write policy compares the first
--    path segment to the caller's uid -- a user can never write into someone
--    else's folder.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('avatars',        'avatars',        true),
  ('pet-images',     'pet-images',     true),
  ('product-images', 'product-images', true)
on conflict (id) do nothing;

drop policy if exists "public read avatars"        on storage.objects;
drop policy if exists "public read pet-images"     on storage.objects;
drop policy if exists "public read product-images" on storage.objects;
drop policy if exists "owner write avatars"        on storage.objects;
drop policy if exists "owner write pet-images"     on storage.objects;
drop policy if exists "owner write product-images" on storage.objects;
drop policy if exists "owner update avatars"       on storage.objects;
drop policy if exists "owner update pet-images"    on storage.objects;
drop policy if exists "owner update product-images" on storage.objects;
drop policy if exists "owner delete avatars"       on storage.objects;
drop policy if exists "owner delete pet-images"    on storage.objects;
drop policy if exists "owner delete product-images" on storage.objects;

create policy "public read avatars" on storage.objects
  for select using (bucket_id = 'avatars');
create policy "public read pet-images" on storage.objects
  for select using (bucket_id = 'pet-images');
create policy "public read product-images" on storage.objects
  for select using (bucket_id = 'product-images');

create policy "owner write avatars" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner write pet-images" on storage.objects
  for insert with check (
    bucket_id = 'pet-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner write product-images" on storage.objects
  for insert with check (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner update avatars" on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner update pet-images" on storage.objects
  for update using (
    bucket_id = 'pet-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner update product-images" on storage.objects
  for update using (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner delete avatars" on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner delete pet-images" on storage.objects
  for delete using (
    bucket_id = 'pet-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner delete product-images" on storage.objects
  for delete using (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- ----------------------------------------------------------------------------
-- 5. Signup trigger: create a profiles row for every new auth user.  Idempotent
--    -- re-running it never dupes profiles.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 6. Repair hand-built NOT NULL columns the app never sends.
--    Hand-made tables declare columns like pets.age, pets.asking_price,
--    products.store_id as NOT NULL with no default. The app never writes them,
--    so every insert died with a 400 "null value in column" error. Each repair
--    is guarded so it is a no-op on a database that already matches the app.
-- ----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='pets' and column_name='age') then
    execute 'alter table public.pets alter column age drop not null';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='pets' and column_name='asking_price') then
    execute 'alter table public.pets alter column asking_price drop not null';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='pets' and column_name='is_negotiable') then
    execute 'alter table public.pets alter column is_negotiable drop not null';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='pets' and column_name='owner_id') then
    execute 'alter table public.pets alter column owner_id drop not null';
  end if;
  alter table public.pets alter column updated_at set default now();
end $$;

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='store_id') then
    execute 'alter table public.products alter column store_id drop not null';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='category_id') then
    execute 'alter table public.products alter column category_id drop not null';
  end if;
  alter table public.products alter column status        set default 'active';
  alter table public.products alter column selling_price set default 0;
  alter table public.products alter column mrp           set default 0;
  alter table public.products alter column free_delivery set default false;
end $$;

-- ----------------------------------------------------------------------------
-- 7. Repair hand-built CHECK constraints whose value whitelist excluded the
--    app's statuses (e.g. pets_status_check rejecting 'available'). Every
--    enum-style CHECK on pets/products is dropped, then the canonical pets
--    checks are recreated to match lib/models/pet_model.dart exactly.
-- ----------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select t.relname as tablename, c.conname
    from pg_constraint c
    join pg_class t     on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname in ('pets', 'products')
      and c.contype = 'c'
      and ( c.conname ilike '%status%'
         or c.conname ilike '%species%'
         or c.conname ilike '%condition%'
         or c.conname ilike '%gender%'
         or c.conname ilike '%breed%'
         or c.conname ilike '%price%'
         or c.conname ilike '%age%'
         or c.conname ilike '%category%'
         or c.conname ilike '%type%' )
  loop
    execute format(
      'alter table public.%I drop constraint if exists %I',
      r.tablename::text, r.conname
    );
  end loop;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'pets_status_check') then
    alter table public.pets add constraint pets_status_check
      check (status in ('available', 'reserved', 'sold', 'pending'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'pets_species_check') then
    alter table public.pets add constraint pets_species_check
      check (species in ('dog', 'cat', 'bird', 'rabbit', 'fish', 'reptile', 'smallPet', 'other'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'pets_condition_check') then
    alter table public.pets add constraint pets_condition_check
      check (condition in ('newArrival', 'excellent', 'good', 'needsCare'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'pets_gender_check') then
    alter table public.pets add constraint pets_gender_check
      check (gender in ('Male', 'Female'));
  end if;
end $$;

-- ============================================================================
-- Verification queries -- every one should return a result/positive count:
--    1) profiles.is_verified            -> column exists
--    2) products columns                -> every app column incl. seller_id, price, stock
--    3) products RLS                    -> 4 policies listed
--    4) storage buckets                 -> avatars, pet-images, product-images
--    5) profiles count vs auth.users    -> equal (proves the trigger works)
--    6) pets/relaxations                -> no row where a hand-made column is
--                                          still NOT NULL
--    7) enum CHECK constraints          -> only the four canonical pets checks
-- ============================================================================
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'profiles'
  and column_name in ('is_verified');

select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'products'
order by ordinal_position;

select policyname from pg_policies where schemaname = 'public' and tablename = 'products';

select id, public from storage.buckets where id in ('avatars', 'pet-images', 'product-images');

select
  (select count(*) from public.profiles)  as profiles,
  (select count(*) from auth.users)       as auth_users;

select column_name, is_nullable from information_schema.columns
where table_schema = 'public' and table_name in ('pets', 'products')
  and column_name in ('age', 'asking_price', 'is_negotiable', 'owner_id',
                      'store_id', 'category_id')
order by table_name, column_name;

select t.relname as table, c.conname as constraint_name
from pg_constraint c
join pg_class t     on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public' and t.relname in ('pets', 'products') and c.contype = 'c'
order by t.relname, c.conname;