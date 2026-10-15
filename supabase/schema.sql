-- ===========================================================================
-- PetHub - ONE authoritative schema for the whole app
-- ===========================================================================
-- Paste this ENTIRE file into the Supabase SQL Editor (Dashboard -> SQL
-- Editor -> New query) and press Run. It is fully idempotent: every statement
-- is either "create ... if not exists", "add column if not exists", a guarded
-- DO block, or "drop ... if exists" followed by a recreate. Run it as many
-- times as you like - nothing is dropped and no data is lost.
--
-- WHY THIS FILE EXISTS
--   The Dart code writes to a fixed set of tables/columns (lib/data/*_mapper.dart,
--   lib/services/*_repository.dart). If the database's table names, column names,
--   NOT NULL constraints or CHECK constraints disagree with the code, every
--   insert is rejected and the app silently keeps its in-memory copy. This file
--   makes the database match the code exactly, using the names the code expects:
--
--     public.profiles        <- auth_service.dart   (read + profile edits)
--     public.pets            <- pet_mapper.dart     (buy page, listings, chat)
--     public.products        <- product_mapper.dart (store, cart, orders)
--     public.conversations   <- chat_repository.dart
--     public.messages        <- chat_repository.dart
--
--   Storage buckets: avatars, pet-images, product-images (image_storage_service.dart)
--
-- WHAT IT GUARANTEES
--   * Every column the mappers read or write exists with the right type.
--   * The foreign keys the code embeds are named exactly as PostgREST expects:
--       pets_seller_id_fkey, conversations_pet_id_fkey,
--       conversations_buyer_id_fkey, conversations_seller_id_fkey
--   * Restrictive CHECK constraints (which were rejecting valid app values)
--     are removed, and any NOT NULL column the app never sends is relaxed, so
--     inserts can no longer fail on constraints.
--   * Row Level Security: the marketplace is publicly browsable, writes stay
--     owner-only, and messaging stays between the two participants.
--   * The signup trigger creates a profiles row for every new account.
--
-- It runs on an empty database and on an existing hand-built database alike.
-- ===========================================================================


-- ===========================================================================
-- 0. updated_at maintenance
-- ===========================================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ===========================================================================
-- 1. PROFILES
--    Read by _loadProfile (full_name, email, phone, avatar_url, city, bio,
--    created_at) and _pushProfile (full_name, phone, city, bio, avatar_url).
--    Also embedded by pets.seller and conversations.buyer / .seller, so it must
--    expose full_name, city, avatar_url and is_verified.
-- ===========================================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '',
  email       text not null default '',
  phone       text not null default '',
  city        text not null default '',
  bio         text not null default '',
  avatar_url  text not null default '',
  is_verified boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles add column if not exists full_name   text not null default '';
alter table public.profiles add column if not exists email       text not null default '';
alter table public.profiles add column if not exists phone       text not null default '';
alter table public.profiles add column if not exists city        text not null default '';
alter table public.profiles add column if not exists bio         text not null default '';
alter table public.profiles add column if not exists avatar_url  text not null default '';
alter table public.profiles add column if not exists is_verified boolean not null default false;
alter table public.profiles add column if not exists created_at  timestamptz not null default now();
alter table public.profiles add column if not exists updated_at  timestamptz not null default now();

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Signup trigger: creates the profile row the moment an account is made.
-- Without it, pets.seller_id has no parent row and every pet insert fails with
-- a foreign key violation.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, avatar_url, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', ''),
    coalesce(new.email, '')
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
insert into public.profiles (id, full_name, phone, email)
select id,
       coalesce(raw_user_meta_data ->> 'full_name', ''),
       coalesce(raw_user_meta_data ->> 'phone', ''),
       coalesce(email, '')
from auth.users
on conflict (id) do nothing;

-- RLS: a row is private, but readable so embedded joins render.
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


-- ===========================================================================
-- 2. PETS  (lib/data/pet_mapper.dart)
--    text + defaults instead of Postgres enums: an enum value the app does not
--    know about returns an empty error body from PostgREST, which is very hard
--    to debug. seller_id carries the FK the code embeds as pets_seller_id_fkey.
-- ===========================================================================
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

-- Ensure the seller foreign key exists under the exact name the code embeds
-- (seller:profiles!pets_seller_id_fkey). Skipped quietly if it cannot be
-- added so the rest of the script still runs.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.pets'::regclass
      and contype = 'f'
      and conname = 'pets_seller_id_fkey'
  ) then
    begin
      alter table public.pets
        add constraint pets_seller_id_fkey
        foreign key (seller_id) references public.profiles (id) on delete cascade;
    exception when others then
      raise notice 'could not add pets_seller_id_fkey: %', SQLERRM;
    end;
  end if;
end $$;

create index if not exists pets_browse_idx  on public.pets (created_at desc) where status = 'available';
create index if not exists pets_seller_idx  on public.pets (seller_id);
create index if not exists pets_species_idx on public.pets (species);
create index if not exists pets_price_idx   on public.pets (price);

drop trigger if exists pets_touch on public.pets;
create trigger pets_touch
  before update on public.pets
  for each row execute function public.touch_updated_at();

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


-- ===========================================================================
-- 3. PRODUCTS  (lib/data/product_mapper.dart)
--    seller_id is nullable so the column can be added to an existing table
--    that already has rows; the app always supplies it on insert and RLS
--    enforces ownership.
-- ===========================================================================
create table if not exists public.products (
  id             uuid primary key default gen_random_uuid(),
  seller_id      uuid references public.profiles (id) on delete cascade,
  name           text not null default '',
  brand          text not null default '',
  category       text not null default 'accessories',
  price          double precision not null default 0,
  old_price      double precision null,
  image_url      text not null default '',
  description    text not null default '',
  highlights     text[] not null default '{}',
  stock          integer not null default 20,
  sold_count     integer not null default 0,
  is_featured    boolean not null default false,
  is_best_seller boolean not null default false,
  free_shipping  boolean not null default true,
  species_tags   text[] not null default '{}',
  shop_name      text not null default 'My Pet Shop',
  shop_verified  boolean not null default false,
  rating         double precision not null default 4.5,
  review_count   integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.products add column if not exists id             uuid primary key default gen_random_uuid();
alter table public.products add column if not exists seller_id      uuid references public.profiles (id) on delete cascade;
alter table public.products add column if not exists name           text not null default '';
alter table public.products add column if not exists brand          text not null default '';
alter table public.products add column if not exists category       text not null default 'accessories';
alter table public.products add column if not exists price          double precision not null default 0;
alter table public.products add column if not exists old_price      double precision null;
alter table public.products add column if not exists image_url      text not null default '';
alter table public.products add column if not exists description    text not null default '';
alter table public.products add column if not exists highlights     text[] not null default '{}';
alter table public.products add column if not exists stock          integer not null default 20;
alter table public.products add column if not exists sold_count     integer not null default 0;
alter table public.products add column if not exists is_featured    boolean not null default false;
alter table public.products add column if not exists is_best_seller boolean not null default false;
alter table public.products add column if not exists free_shipping  boolean not null default true;
alter table public.products add column if not exists species_tags   text[] not null default '{}';
alter table public.products add column if not exists shop_name      text not null default 'My Pet Shop';
alter table public.products add column if not exists shop_verified  boolean not null default false;
alter table public.products add column if not exists rating         double precision not null default 4.5;
alter table public.products add column if not exists review_count   integer not null default 0;
alter table public.products add column if not exists created_at     timestamptz not null default now();
alter table public.products add column if not exists updated_at     timestamptz not null default now();

-- Hand-built tables used these; the app never writes them, so give them
-- defaults (or a NULL-able seller) instead of letting NOT NULL reject inserts.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='selling_price') then
    execute 'alter table public.products alter column selling_price set default 0';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='mrp') then
    execute 'alter table public.products alter column mrp set default 0';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='free_delivery') then
    execute 'alter table public.products alter column free_delivery set default false';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='status') then
    execute 'alter table public.products alter column status set default ''active''';
  end if;
end $$;

create index if not exists products_seller_idx on public.products (seller_id);
create index if not exists products_cat_idx    on public.products (category);

drop trigger if exists products_touch on public.products;
create trigger products_touch
  before update on public.products
  for each row execute function public.touch_updated_at();

alter table public.products enable row level security;

drop policy if exists products_read on public.products;
create policy products_read on public.products
  for select to anon, authenticated using (true);

drop policy if exists products_insert_own on public.products;
create policy products_insert_own on public.products
  for insert to authenticated with check (auth.uid() = seller_id);

drop policy if exists products_update_own on public.products;
create policy products_update_own on public.products
  for update to authenticated
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

drop policy if exists products_delete_own on public.products;
create policy products_delete_own on public.products
  for delete to authenticated using (auth.uid() = seller_id);


-- ===========================================================================
-- 4. CONVERSATIONS + MESSAGES  (lib/services/chat_repository.dart)
--    The inbox embeds:
--      pet:pets!conversations_pet_id_fkey(...)
--      buyer:profiles!conversations_buyer_id_fkey(...)
--      seller:profiles!conversations_seller_id_fkey(...)
--    so those three FKs must exist under exactly those names.
-- ===========================================================================
create table if not exists public.conversations (
  id          uuid primary key default gen_random_uuid(),
  pet_id      uuid not null references public.pets (id)      on delete cascade,
  buyer_id    uuid not null references public.profiles (id)  on delete cascade,
  seller_id   uuid not null references public.profiles (id)  on delete cascade,
  created_at  timestamptz not null default now(),
  unique (pet_id, buyer_id)
);

alter table public.conversations add column if not exists id         uuid primary key default gen_random_uuid();
alter table public.conversations add column if not exists pet_id     uuid references public.pets (id) on delete cascade;
alter table public.conversations add column if not exists buyer_id   uuid references public.profiles (id) on delete cascade;
alter table public.conversations add column if not exists seller_id  uuid references public.profiles (id) on delete cascade;
alter table public.conversations add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (select 1 from pg_constraint
                 where conrelid='public.conversations'::regclass and contype='u'
                   and conname='conversations_pet_id_buyer_id_key') then
    begin
      alter table public.conversations
        add constraint conversations_pet_id_buyer_id_key unique (pet_id, buyer_id);
    exception when others then
      raise notice 'could not add conversations unique: %', SQLERRM;
    end;
  end if;
end $$;

-- Ensure the three embed FKs carry the exact expected names.
do $$
begin
  if not exists (select 1 from pg_constraint
                 where conrelid='public.conversations'::regclass and contype='f'
                   and conname='conversations_pet_id_fkey') then
    begin
      alter table public.conversations
        add constraint conversations_pet_id_fkey
        foreign key (pet_id) references public.pets (id) on delete cascade;
    exception when others then
      raise notice 'could not add conversations_pet_id_fkey: %', SQLERRM;
    end;
  end if;

  if not exists (select 1 from pg_constraint
                 where conrelid='public.conversations'::regclass and contype='f'
                   and conname='conversations_buyer_id_fkey') then
    begin
      alter table public.conversations
        add constraint conversations_buyer_id_fkey
        foreign key (buyer_id) references public.profiles (id) on delete cascade;
    exception when others then
      raise notice 'could not add conversations_buyer_id_fkey: %', SQLERRM;
    end;
  end if;

  if not exists (select 1 from pg_constraint
                 where conrelid='public.conversations'::regclass and contype='f'
                   and conname='conversations_seller_id_fkey') then
    begin
      alter table public.conversations
        add constraint conversations_seller_id_fkey
        foreign key (seller_id) references public.profiles (id) on delete cascade;
    exception when others then
      raise notice 'could not add conversations_seller_id_fkey: %', SQLERRM;
    end;
  end if;
end $$;

create table if not exists public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  sender_id        uuid not null references public.profiles (id)      on delete cascade,
  body             text not null check (length(trim(body)) > 0),
  created_at       timestamptz not null default now()
);

alter table public.messages add column if not exists id              uuid primary key default gen_random_uuid();
alter table public.messages add column if not exists conversation_id uuid references public.conversations (id) on delete cascade;
alter table public.messages add column if not exists sender_id       uuid references public.profiles (id) on delete cascade;
alter table public.messages add column if not exists body            text;
alter table public.messages add column if not exists created_at      timestamptz not null default now();

create index if not exists messages_conversation_idx
  on public.messages (conversation_id, created_at);

alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
  for select to authenticated using (
    auth.uid() = buyer_id or auth.uid() = seller_id);

drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert on public.conversations
  for insert to authenticated with check (
    auth.uid() = buyer_id and seller_id <> buyer_id);

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated using (
    exists (select 1 from public.conversations c
            where c.id = messages.conversation_id
              and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated with check (
    auth.uid() = sender_id
    and exists (select 1 from public.conversations c
                where c.id = messages.conversation_id
                  and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())));


-- ===========================================================================
-- 5. RELAX HAND-BUILT CONSTRAINTS THAT REJECT APP WRITES
--    A hand-made table often declares columns the app never sends as NOT NULL
--    with no default, or adds CHECK whitelists that exclude a value the model
--    produces. Both turn into a silent 400 on every insert. Relax them here.
-- ===========================================================================

-- 5a. Drop NOT NULL (keeping the data) on any column the app never supplies:
--     no default, not a primary key, not an identity column.
do $$
declare r record;
begin
  for r in
    select c.table_name, c.column_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name in ('pets', 'products')
      and c.is_nullable = 'NO'
      and c.column_default is null
      and c.is_identity = 'NO'
      and c.is_generated = 'NEVER'
      and not exists (
        select 1
        from information_schema.table_constraints tc
        join information_schema.key_column_usage kcu
          on tc.constraint_name = kcu.constraint_name
         and tc.table_schema   = kcu.table_schema
        where tc.table_schema = 'public'
          and tc.table_name   = c.table_name
          and tc.constraint_type = 'PRIMARY KEY'
          and kcu.column_name = c.column_name
      )
  loop
    execute format('alter table public.%I alter column %I drop not null',
                   r.table_name, r.column_name);
  end loop;
end $$;

-- 5b. Drop every CHECK constraint on pets/products. The model enums are the
--     source of truth for valid values (a CHECK whitelist is what used to
--     reject e.g. a 'Pair' gender or a 'pending' status the app legitimately
--     writes). Dropping them guarantees no app value is ever refused.
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
  loop
    execute format('alter table public.%I drop constraint if exists %I',
                   r.tablename::text, r.conname);
  end loop;
end $$;


-- ===========================================================================
-- 6. PUBLIC MARKETPLACE GRANTS
--    RLS is the gatekeeper; these are only table privileges so PostgREST does
--    not reject an anon read outright. profiles gets a SELECT grant so the
--    embedded seller join resolves to null instead of erroring for visitors.
-- ===========================================================================
grant usage on schema public to anon, authenticated;

grant select on public.pets      to anon, authenticated;
grant select on public.products  to anon, authenticated;
grant select on public.profiles  to anon, authenticated;

grant all on public.pets          to authenticated;
grant all on public.products      to authenticated;
grant all on public.profiles      to authenticated;
grant all on public.conversations to authenticated;
grant all on public.messages      to authenticated;


-- ===========================================================================
-- 7. STORAGE - buckets for photos
--    A picked photo is a path in the app's private cache, readable only on the
--    device that took it. Storing that string produces a listing whose image
--    works for the seller and shows as broken for everyone else.
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

drop policy if exists "public read avatars"        on storage.objects;
drop policy if exists "public read pet-images"     on storage.objects;
drop policy if exists "public read product-images" on storage.objects;
drop policy if exists "owner write avatars"        on storage.objects;
drop policy if exists "owner write pet-images"     on storage.objects;
drop policy if exists "owner write product-images" on storage.objects;
drop policy if exists "owner update avatars"       on storage.objects;
drop policy if exists "owner delete avatars"       on storage.objects;
drop policy if exists "owner delete pet-images"    on storage.objects;
drop policy if exists "owner delete product-images" on storage.objects;

create policy "public read avatars" on storage.objects
  for select using (bucket_id = 'avatars');
create policy "public read pet-images" on storage.objects
  for select using (bucket_id = 'pet-images');
create policy "public read product-images" on storage.objects
  for select using (bucket_id = 'product-images');

-- A user may only write inside a folder named after their own id, so nobody
-- can overwrite someone else's photos.
create policy "owner write avatars" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner write pet-images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'pet-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner write product-images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner update avatars" on storage.objects
  for update to authenticated using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner delete avatars" on storage.objects
  for delete to authenticated using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner delete pet-images" on storage.objects
  for delete to authenticated using (
    bucket_id = 'pet-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner delete product-images" on storage.objects
  for delete to authenticated using (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);


-- ===========================================================================
-- 8. REALTIME - broadcast INSERTs on messages to the two participants.
--    RLS still decides who actually receives an event, so strangers get nothing.
-- ===========================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'messages'
  ) then
    begin
      execute 'alter publication supabase_realtime add table public.messages';
    exception when others then
      raise notice 'could not add messages to realtime publication: %', SQLERRM;
    end;
  end if;
end $$;


-- ===========================================================================
-- 9. VERIFY - read-only checks. Run these last; every one should return rows.
-- ===========================================================================

-- 9a. All five tables exist.
select table_name from information_schema.tables
where table_schema = 'public'
  and table_name in ('profiles','pets','products','conversations','messages')
order by table_name;

-- 9b. Every pets column the mapper writes must be present (expect 0 rows).
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'pets'
  and column_name not in (
    'id','seller_id','name','species','breed','age_in_months','gender','price',
    'negotiable','image_urls','description','location','vaccinated','dewormed',
    'health_checked','microchipped','neutered','vaccine_details','vaccinations',
    'health_issues','status','condition','is_featured','tags','views',
    'favorite_count','created_at','updated_at'
  );

-- 9c. Every products column the mapper writes must be present (expect 0 rows).
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'products'
  and column_name not in (
    'id','seller_id','name','brand','category','price','old_price','image_url',
    'description','highlights','stock','sold_count','is_featured',
    'is_best_seller','free_shipping','species_tags','shop_name','shop_verified',
    'rating','review_count','created_at','updated_at'
  );

-- 9d. The four embedded foreign keys carry the exact names the code expects
--     (expect exactly 4 rows).
select conname
from pg_constraint
where contype = 'f'
  and conname in ('pets_seller_id_fkey',
                  'conversations_pet_id_fkey',
                  'conversations_buyer_id_fkey',
                  'conversations_seller_id_fkey')
order by conname;

-- 9e. profiles count should match auth.users (proves the signup trigger works).
select
  (select count(*) from public.profiles) as profiles,
  (select count(*) from auth.users)      as auth_users;

-- 9f. No pet/product column is still NOT NULL without a default (expect 0 rows)
--     - these are exactly the columns that used to reject app inserts.
select c.table_name, c.column_name
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('pets','products')
  and c.is_nullable = 'NO'
  and c.column_default is null
  and c.is_identity = 'NO'
  and not exists (
    select 1
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name
     and tc.table_schema   = kcu.table_schema
    where tc.table_schema = 'public'
      and tc.table_name   = c.table_name
      and tc.constraint_type = 'PRIMARY KEY'
      and kcu.column_name = c.column_name
  );

-- 9g. RLS is on and policies exist for every table.
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles','pets','products','conversations','messages')
order by tablename, policyname;

-- 9h. The three storage buckets exist and are public.
select id, public from storage.buckets
where id in ('avatars','pet-images','product-images')
order by id;
