-- Noon Report: схема облака. Выполнить один раз в Supabase → SQL Editor.
-- Две таблицы одной формы: сам объект лежит в data (jsonb), рядом служебные поля.
--   updated_at — миллисекунды по часам устройства: по нему решается конфликт
--   server_at  — часы сервера: по нему устройство спрашивает «что нового с прошлого раза»
--   deleted    — надгробие: запись удалена, другие устройства должны её убрать

create table if not exists public.voyages (
  id         text primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at bigint not null default 0,
  deleted    boolean not null default false,
  server_at  timestamptz not null default now()
);

create table if not exists public.entries (
  id         text primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  voyage_id  text not null default '',
  date       text not null default '',
  rtype      text not null default 'NOON',
  seq        integer not null default 0,
  data       jsonb not null default '{}'::jsonb,
  updated_at bigint not null default 0,
  deleted    boolean not null default false,
  server_at  timestamptz not null default now()
);

create index if not exists voyages_user_server on public.voyages (user_id, server_at);
create index if not exists entries_user_server on public.entries (user_id, server_at);
create index if not exists entries_user_voyage on public.entries (user_id, voyage_id, date);

-- Не затирать новое старым: upsert с более старым updated_at молча пропускается,
-- устройство на следующем обмене получит свежую версию. server_at ставит сервер.
create or replace function public.keep_newest() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return null;
  end if;
  new.server_at := now();
  return new;
end $$;

drop trigger if exists voyages_keep_newest on public.voyages;
create trigger voyages_keep_newest before insert or update on public.voyages
  for each row execute function public.keep_newest();
drop trigger if exists entries_keep_newest on public.entries;
create trigger entries_keep_newest before insert or update on public.entries
  for each row execute function public.keep_newest();

-- Доступ: каждый видит и меняет только своё.
alter table public.voyages enable row level security;
alter table public.entries enable row level security;

drop policy if exists voyages_own on public.voyages;
create policy voyages_own on public.voyages
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists entries_own on public.entries;
create policy entries_own on public.entries
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.voyages, public.entries to authenticated;
