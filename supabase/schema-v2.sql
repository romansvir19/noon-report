-- Noon Report, вторая очередь: заметки и текущий черновик.
-- Выполнить один раз в Supabase → SQL Editor (после schema.sql).
create table if not exists public.reminders (
  id         text primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at bigint not null default 0,
  deleted    boolean not null default false,
  server_at  timestamptz not null default now()
);
create table if not exists public.drafts (
  id         text primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at bigint not null default 0,
  deleted    boolean not null default false,
  server_at  timestamptz not null default now()
);
create index if not exists reminders_user_server on public.reminders (user_id, server_at);
create index if not exists drafts_user_server    on public.drafts (user_id, server_at);

drop trigger if exists reminders_keep_newest on public.reminders;
create trigger reminders_keep_newest before insert or update on public.reminders
  for each row execute function public.keep_newest();
drop trigger if exists drafts_keep_newest on public.drafts;
create trigger drafts_keep_newest before insert or update on public.drafts
  for each row execute function public.keep_newest();

alter table public.reminders enable row level security;
alter table public.drafts enable row level security;
drop policy if exists reminders_own on public.reminders;
create policy reminders_own on public.reminders
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists drafts_own on public.drafts;
create policy drafts_own on public.drafts
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update, delete on public.reminders, public.drafts to authenticated;
