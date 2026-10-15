-- ============================================================================
-- SUPERSEDED - use supabase/schema.sql instead (single authoritative file
-- covering profiles, pets, products, chat, RLS, storage and realtime).
-- ============================================================================
-- public_marketplace.sql
-- Makes pets and products browsable by ANYONE - including visitors who are
-- not signed in (public marketplace). Writes stay owner-only.
--
-- profiles stay visible only to signed-in users; the anon select grant does
-- NOT expose rows (RLS still denies), it only lets the embedded seller join
-- resolve to null instead of erroring.
-- Safe to run twice. Run in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Restore public browse policies (drop only, then recreate).
-- ----------------------------------------------------------------------------
drop policy if exists pets_select on public.pets;
create policy pets_select on public.pets
  for select to anon, authenticated using (true);

drop policy if exists products_read on public.products;
create policy products_read on public.products
  for select to anon, authenticated using (true);

-- ----------------------------------------------------------------------------
-- 2. Grants: without table privileges PostgREST rejects anon reads outright.
--    RLS remains the gatekeeper - profiles rows stay hidden from anon.
-- ----------------------------------------------------------------------------
grant select on public.pets to anon;
grant select on public.products to anon;
grant select on public.profiles to anon;

-- ============================================================================
-- Verification: both policies should list the anon role, and anon should have
-- SELECT on the three tables.
-- ============================================================================
select tablename, policyname, roles from pg_policies
where schemaname = 'public' and tablename in ('pets', 'products')
  and cmd = 'SELECT'
order by tablename, policyname;

select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'anon'
  and table_name in ('pets', 'products', 'profiles')
order by table_name;