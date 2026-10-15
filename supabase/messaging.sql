-- ============================================================================
-- SUPERSEDED - use supabase/schema.sql instead (single authoritative file
-- covering profiles, pets, products, chat, RLS, storage and realtime).
-- ============================================================================
-- messaging.sql
-- Real buyer <-> seller messaging. A conversation lives on a pet listing, so
-- both sides always know what they are talking about. Messages are broadcast
-- to the two participants instantly through Supabase Realtime.
--
-- Runs against an already-provisioned project (run_this_first.sql +
-- connect_supabase.sql first). Safe to re-run. Run in SQL Editor -> Run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tables. One conversation per (pet, buyer) + a message log per conversation.
-- ----------------------------------------------------------------------------
create table if not exists public.conversations (
  id          uuid primary key default gen_random_uuid(),
  pet_id      uuid not null references public.pets(id)      on delete cascade,
  buyer_id    uuid not null references public.profiles(id)  on delete cascade,
  seller_id   uuid not null references public.profiles(id)  on delete cascade,
  created_at  timestamptz not null default now(),
  unique (pet_id, buyer_id)
);

create table if not exists public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations(id) on delete cascade,
  sender_id        uuid not null references public.profiles(id)      on delete cascade,
  body             text not null check (length(trim(body)) > 0),
  created_at       timestamptz not null default now()
);

create index if not exists messages_conversation_idx
  on public.messages (conversation_id, created_at);

-- ----------------------------------------------------------------------------
-- 2. Row Level Security.
--    - conversations: anyone signed in may start one, but only the buyer and
--      the seller can read it.
--    - messages: participants only; you can only write as yourself.
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 3. Realtime: broadcast INSERTs on messages to the two participants. RLS still
--    decides who actually receives an event, so strangers get nothing.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'messages'
  ) then
    execute 'alter publication supabase_realtime add table public.messages';
  end if;
end $$;

-- ============================================================================
-- Verification.
-- ============================================================================
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename in ('conversations', 'messages')
order by tablename, policyname;

select schemaname, tablename from pg_publication_tables
where pubname = 'supabase_realtime' and tablename = 'messages';
