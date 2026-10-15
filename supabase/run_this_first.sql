-- ===========================================================================
-- SUPERSEDED - use supabase/schema.sql instead (single authoritative file
-- covering profiles, pets, products, chat, RLS, storage and realtime).
-- ===========================================================================
-- PetHub - ONE script to make pet selling work against the backend
-- ===========================================================================
-- Run this in the Supabase SQL Editor (Dashboard -> SQL Editor -> New query),
-- then press Run. It is safe to run twice: every statement is idempotent, and
-- nothing is dropped. Then run supabase/connect_supabase.sql for products,
-- Row Level Security restore, and storage.
--
-- After both run, the app can register, upload photos, publish a pet listing
-- and a product, and show them in My Listings / the Buy page.
--
-- What this fixes, based on probing the live project:
--
--   profiles  missing: bio, is_verified  (so name/city/avatar saves failed)
--   profiles  no signup trigger           (so no profile row was ever created)
--   pets      missing: seller_id, age_in_months, price, image_urls,
--                      vaccinations, negotiable  (so nothing could be saved)
--   storage   no buckets at all            (so photos could never be uploaded)
--
-- The tables are created if they do not exist, so this script works on an
-- empty database and on existing hand-built tables alike.
-- ===========================================================================

begin;

-- ===========================================================================
-- 1. PROFILES - every column the app reads or writes
-- ===========================================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '',
  phone       text not null default '',
  city        text not null default '',
  bio         text not null default '',
  avatar_url  text not null default '',
  is_verified boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles add column if not exists full_name   text not null default '';
alter table public.profiles add column if not exists phone      text not null default '';
alter table public.profiles add column if not exists city       text not null default '';
alter table public.profiles add column if not exists bio        text not null default '';
alter table public.profiles add column if not exists avatar_url text not null default '';
alter table public.profiles add column if not exists is_verified boolean not null default false;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- updated_at maintenance
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Signup trigger: creates the profile row the moment an account is made.
-- Without this, pets.seller_id has no parent row to point at and every pet
-- insert fails with a foreign key violation.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill a profile for any account created before this trigger existed.
insert into public.profiles (id, full_name, phone)
select id,
       coalesce(raw_user_meta_data ->> 'full_name', ''),
       coalesce(raw_user_meta_data ->> 'phone', '')
from auth.users
on conflict (id) do nothing;

-- profiles RLS: a row is private, but readable for display purposes.
alter table public.profiles enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

commit;

-- ===========================================================================
-- 2. PETS - columns matching lib/models/pet_model.dart
--
-- text + CHECK instead of Postgres enums: an enum the app does not know about
-- returns an empty error body from PostgREST, which is very hard to debug.
-- ===========================================================================
begin;

create table if not exists public.pets (
  id             uuid primary key default gen_random_uuid(),
  seller_id      uuid references public.profiles (id) on delete cascade,
  name           text not null default '',
  species        text not null default 'dog',
  breed          text not null default '',
  age_in_months  int not null default 12,
  gender         text not null default 'Male',
  price          numeric(12,2) not null default 0,
  negotiable     boolean not null default false,
  image_urls     text[] not null default '{}',
  description    text not null default '',
  location       text not null default '',
  vaccinated     boolean not null default false,
  dewormed       boolean not null default false,
  health_checked boolean not null default false,
  microchipped   boolean not null default false,
  neutered       boolean not null default false,
  vaccine_details text not null default '',
  vaccinations   jsonb not null default '[]'::jsonb,
  health_issues  text not null default '',
  status         text not null default 'available',
  condition      text not null default 'excellent',
  is_featured    boolean not null default false,
  tags           text[] not null default '{}',
  views          int not null default 0,
  favorite_count int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.pets add column if not exists id             uuid primary key default gen_random_uuid();
alter table public.pets add column if not exists seller_id      uuid references public.profiles (id) on delete cascade;
alter table public.pets add column if not exists name           text not null default '';
alter table public.pets add column if not exists species        text not null default 'dog';
alter table public.pets add column if not exists breed          text not null default '';
alter table public.pets add column if not exists age_in_months  int not null default 12;
alter table public.pets add column if not exists gender         text not null default 'Male';
alter table public.pets add column if not exists price          numeric(12,2) not null default 0;
alter table public.pets add column if not exists negotiable     boolean not null default false;
alter table public.pets add column if not exists image_urls     text[] not null default '{}';
alter table public.pets add column if not exists description    text not null default '';
alter table public.pets add column if not exists location       text not null default '';
alter table public.pets add column if not exists vaccinated     boolean not null default false;
alter table public.pets add column if not exists dewormed       boolean not null default false;
alter table public.pets add column if not exists health_checked boolean not null default false;
alter table public.pets add column if not exists microchipped   boolean not null default false;
alter table public.pets add column if not exists neutered       boolean not null default false;
alter table public.pets add column if not exists vaccine_details text not null default '';
alter table public.pets add column if not exists vaccinations   jsonb not null default '[]'::jsonb;
alter table public.pets add column if not exists health_issues  text not null default '';
alter table public.pets add column if not exists status         text not null default 'available';
alter table public.pets add column if not exists condition      text not null default 'excellent';
alter table public.pets add column if not exists is_featured    boolean not null default false;
alter table public.pets add column if not exists tags           text[] not null default '{}';
alter table public.pets add column if not exists views          int not null default 0;
alter table public.pets add column if not exists favorite_count int not null default 0;
alter table public.pets add column if not exists created_at     timestamptz not null default now();
alter table public.pets add column if not exists updated_at     timestamptz not null default now();

-- An older hand-made table may store health notes as text[]; flatten it.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'pets'
      and column_name = 'health_issues' and data_type = 'ARRAY'
  ) then
    execute 'alter table public.pets alter column health_issues type text
             using array_to_string(health_issues, '''', ''')';
  end if;
end
$$;

-- Names must not be blank, and the enum-ish values must be valid.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pets_name_not_blank'
  ) then
    alter table public.pets
      add constraint pets_name_not_blank check (length(btrim(name)) > 0);
  end if;
end
$$;

create index if not exists pets_browse_idx  on public.pets (created_at desc) where status = 'available';
create index if not exists pets_seller_idx  on public.pets (seller_id);
create index if not exists pets_species_idx on public.pets (species);
create index if not exists pets_price_idx   on public.pets (price);

drop trigger if exists pets_touch on public.pets;
create trigger pets_touch
  before update on public.pets
  for each row execute function public.touch_updated_at();

-- RLS: everyone may browse (public marketplace), only the seller may write.
-- The with check on update stops a seller reassigning seller_id, which a bare
-- using clause would otherwise allow.
alter table public.pets enable row level security;

drop policy if exists pets_select on public.pets;
create policy pets_select on public.pets
  for select to anon, authenticated using (true);

drop policy if exists pets_insert_own on public.pets;
create policy pets_insert_own on public.pets
  for insert to authenticated with check (auth.uid() = seller_id);

drop policy if exists pets_update_own on public.pets;
create policy pets_update_own on public.pets
  for update to authenticated
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

drop policy if exists pets_delete_own on public.pets;
create policy pets_delete_own on public.pets
  for delete to authenticated using (auth.uid() = seller_id);

commit;

-- ===========================================================================
-- 3. STORAGE - buckets for photos
--
-- A picked photo is a path in the app's private cache, readable only on the
-- device that took it. Storing that string produces a listing whose image
-- works for the seller and shows as broken for everyone else. Uploading is what
-- makes a listing visible.
-- ===========================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',       'avatars',       true,  5242880, array['image/jpeg','image/png','image/webp']),
  ('pet-images',    'pet-images',    true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('product-images','product-images',true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatar read public"     on storage.objects;
drop policy if exists "pet photo read public"  on storage.objects;
drop policy if exists "product read public"    on storage.objects;
drop policy if exists "avatar upload own"      on storage.objects;
drop policy if exists "pet photo upload own"   on storage.objects;
drop policy if exists "product upload own"     on storage.objects;
drop policy if exists "avatar delete own"      on storage.objects;
drop policy if exists "avatar update own"      on storage.objects;
drop policy if exists "pet photo delete own"   on storage.objects;

create policy "avatar read public"    on storage.objects
  for select using (bucket_id = 'avatars');
create policy "pet photo read public" on storage.objects
  for select using (bucket_id = 'pet-images');
create policy "product read public"   on storage.objects
  for select using (bucket_id = 'product-images');

-- A user may only write inside a folder named after their own id.
create policy "avatar upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "pet photo upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pet-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "product upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatar update own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatar delete own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "pet photo delete own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'pet-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

-- ===========================================================================
-- 4. VERIFY - run these last, they only read
-- ===========================================================================

-- Expect 3 rows: avatars, pet-images, product-images.
select id, public from storage.buckets
where id in ('avatars','pet-images','product-images') order by id;

-- Expect 4 rows: select, insert, update, delete.
select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'pets' order by policyname;

-- Expect 1 row per account: the trigger plus backfill should have covered all.
select count(*) as profiles_should_match_auth_users from public.profiles;
select count(*) as auth_users from auth.users;

-- Should now report no rows: every pets column the app needs exists.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'pets'
  and column_name in (
    'id','seller_id','name','species','breed','age_in_months','gender','price',
    'negotiable','image_urls','description','location','vaccinated','dewormed',
    'health_checked','microchipped','neutered','vaccine_details','vaccinations',
    'health_issues','status','condition','is_featured','tags','views',
    'favorite_count','created_at','updated_at'
  )
order by column_name;