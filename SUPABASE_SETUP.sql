-- ============================================================
-- KTAK Mission Room V1.6 Online - Supabase backend
-- 執行位置：Supabase Dashboard > SQL Editor
-- 本檔可重複執行（政策會先 drop 再建立）
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.ktak_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  password_hash text,
  creator_user_id uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ktak_room_members (
  room_id uuid not null references public.ktak_rooms(id) on delete cascade,
  user_id uuid not null,
  nick text not null,
  role text not null check (role in ('commander','tactical','recon','observer')),
  joined_at timestamptz not null default now(),
  primary key (room_id,user_id)
);

create table if not exists public.ktak_brief (
  room_id uuid primary key references public.ktak_rooms(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.ktak_map_items (
  id uuid primary key,
  room_id uuid not null references public.ktak_rooms(id) on delete cascade,
  owner_id uuid not null,
  data jsonb not null,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
create index if not exists ktak_map_items_room_idx on public.ktak_map_items(room_id);

create table if not exists public.ktak_board_settings (
  room_id uuid primary key references public.ktak_rooms(id) on delete cascade,
  canvas_w integer not null default 2000 check (canvas_w between 1200 and 5000),
  canvas_h integer not null default 1400 check (canvas_h between 800 and 3500),
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.ktak_board_pages (
  id uuid primary key,
  room_id uuid not null references public.ktak_rooms(id) on delete cascade,
  name text not null,
  sort_index integer not null default 0,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
create index if not exists ktak_board_pages_room_idx on public.ktak_board_pages(room_id,sort_index);

create table if not exists public.ktak_board_objects (
  id uuid primary key,
  room_id uuid not null references public.ktak_rooms(id) on delete cascade,
  page_id uuid not null references public.ktak_board_pages(id) on delete cascade,
  owner_id uuid not null,
  data jsonb not null,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
create index if not exists ktak_board_objects_room_idx on public.ktak_board_objects(room_id);
create index if not exists ktak_board_objects_page_idx on public.ktak_board_objects(page_id);

create table if not exists public.ktak_chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.ktak_rooms(id) on delete cascade,
  sender_id uuid not null,
  sender_name text not null,
  text text not null default '',
  image_path text,
  created_at timestamptz not null default now(),
  check (char_length(text) <= 5000),
  check (text <> '' or image_path is not null)
);
create index if not exists ktak_chat_messages_room_idx on public.ktak_chat_messages(room_id,created_at);

-- ---------- helper authorization functions ----------
create or replace function public.ktak_role(p_room_id uuid)
returns text
language sql stable security definer
set search_path = public
as $$
  select m.role
  from public.ktak_room_members m
  where m.room_id=p_room_id and m.user_id=auth.uid()
  limit 1
$$;

create or replace function public.ktak_is_member(p_room_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists(
    select 1 from public.ktak_room_members m
    where m.room_id=p_room_id and m.user_id=auth.uid()
  )
$$;

create or replace function public.ktak_role_text(p_room_text text)
returns text
language sql stable security definer
set search_path = public
as $$
  select m.role
  from public.ktak_room_members m
  where m.room_id::text=p_room_text and m.user_id=auth.uid()
  limit 1
$$;

-- Keep original owner immutable after insertion.
create or replace function public.ktak_keep_owner()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.owner_id := old.owner_id;
  new.updated_at := now();
  return new;
end
$$;

drop trigger if exists ktak_map_keep_owner on public.ktak_map_items;
create trigger ktak_map_keep_owner before update on public.ktak_map_items
for each row execute function public.ktak_keep_owner();

drop trigger if exists ktak_board_keep_owner on public.ktak_board_objects;
create trigger ktak_board_keep_owner before update on public.ktak_board_objects
for each row execute function public.ktak_keep_owner();

-- ---------- room RPC ----------
create or replace function public.ktak_create_room(p_code text,p_password text,p_nick text)
returns table(room_id uuid,room_code text,member_role text)
language plpgsql security definer
set search_path = public,extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_room uuid;
  v_code text := upper(trim(p_code));
  v_page uuid := gen_random_uuid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_code !~ '^[A-Z0-9_-]{3,24}$' then raise exception 'BAD_ROOM_CODE'; end if;
  if nullif(trim(p_nick),'') is null then raise exception 'BAD_NICK'; end if;

  begin
    insert into public.ktak_rooms(code,password_hash,creator_user_id)
    values (
      v_code,
      case when coalesce(p_password,'')='' then null else extensions.crypt(p_password,extensions.gen_salt('bf')) end,
      v_uid
    )
    returning id into v_room;
  exception when unique_violation then
    raise exception 'ROOM_EXISTS';
  end;

  insert into public.ktak_room_members(room_id,user_id,nick,role)
  values(v_room,v_uid,trim(p_nick),'commander');

  insert into public.ktak_brief(room_id,data,updated_by)
  values(v_room,'{"caseType":"","riskLevel":"中","suspectCount":"","suspectBackground":"","executionMode":"包圍消耗","executionOther":"","civilianCount":"","teamComposition":"","missionNotes":""}'::jsonb,v_uid);

  insert into public.ktak_board_settings(room_id,canvas_w,canvas_h,updated_by)
  values(v_room,2000,1400,v_uid);

  insert into public.ktak_board_pages(id,room_id,name,sort_index,updated_by)
  values(v_page,v_room,'1F',0,v_uid);

  return query select v_room,v_code,'commander'::text;
end
$$;

create or replace function public.ktak_join_room(p_code text,p_password text,p_nick text,p_requested_role text)
returns table(room_id uuid,room_code text,member_role text)
language plpgsql security definer
set search_path = public,extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_room uuid;
  v_hash text;
  v_code text := upper(trim(p_code));
  v_role text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if nullif(trim(p_nick),'') is null then raise exception 'BAD_NICK'; end if;

  select r.id,r.password_hash into v_room,v_hash
  from public.ktak_rooms r where r.code=v_code limit 1;
  if v_room is null then raise exception 'ROOM_NOT_FOUND'; end if;

  if v_hash is not null and extensions.crypt(coalesce(p_password,''),v_hash)<>v_hash then
    raise exception 'BAD_PASSWORD';
  end if;

  v_role := case when p_requested_role in ('tactical','recon','observer') then p_requested_role else 'observer' end;

  insert into public.ktak_room_members(room_id,user_id,nick,role)
  values(v_room,v_uid,trim(p_nick),v_role)
  on conflict(room_id,user_id) do update set nick=excluded.nick;

  select m.role into v_role from public.ktak_room_members m
  where m.room_id=v_room and m.user_id=v_uid;

  return query select v_room,v_code,v_role;
end
$$;

create or replace function public.ktak_set_member_role(p_room_id uuid,p_target_user uuid,p_role text)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_old text;
  v_count integer;
begin
  if public.ktak_role(p_room_id)<>'commander' then raise exception 'COMMANDER_REQUIRED'; end if;
  if p_role not in ('commander','tactical','recon','observer') then raise exception 'BAD_ROLE'; end if;

  select role into v_old from public.ktak_room_members
  where room_id=p_room_id and user_id=p_target_user;
  if v_old is null then raise exception 'MEMBER_NOT_FOUND'; end if;

  if v_old='commander' and p_role<>'commander' then
    select count(*) into v_count from public.ktak_room_members
    where room_id=p_room_id and role='commander';
    if v_count<=1 then raise exception 'LAST_COMMANDER'; end if;
  end if;

  update public.ktak_room_members set role=p_role
  where room_id=p_room_id and user_id=p_target_user;
end
$$;

-- ---------- RLS ----------
alter table public.ktak_rooms enable row level security;
alter table public.ktak_room_members enable row level security;
alter table public.ktak_brief enable row level security;
alter table public.ktak_map_items enable row level security;
alter table public.ktak_board_settings enable row level security;
alter table public.ktak_board_pages enable row level security;
alter table public.ktak_board_objects enable row level security;
alter table public.ktak_chat_messages enable row level security;

drop policy if exists "ktak rooms member read" on public.ktak_rooms;
create policy "ktak rooms member read" on public.ktak_rooms for select to authenticated
using (public.ktak_is_member(id));

drop policy if exists "ktak members read" on public.ktak_room_members;
create policy "ktak members read" on public.ktak_room_members for select to authenticated
using (public.ktak_is_member(room_id));

drop policy if exists "ktak brief read" on public.ktak_brief;
create policy "ktak brief read" on public.ktak_brief for select to authenticated
using (public.ktak_is_member(room_id));
drop policy if exists "ktak brief commander update" on public.ktak_brief;
create policy "ktak brief commander update" on public.ktak_brief for update to authenticated
using (public.ktak_role(room_id)='commander')
with check (public.ktak_role(room_id)='commander');

drop policy if exists "ktak map read" on public.ktak_map_items;
create policy "ktak map read" on public.ktak_map_items for select to authenticated
using (public.ktak_is_member(room_id));
drop policy if exists "ktak map insert" on public.ktak_map_items;
create policy "ktak map insert" on public.ktak_map_items for insert to authenticated
with check (
  public.ktak_role(room_id) in ('commander','tactical','recon')
  and (owner_id=auth.uid() or public.ktak_role(room_id)='commander')
);
drop policy if exists "ktak map update" on public.ktak_map_items;
create policy "ktak map update" on public.ktak_map_items for update to authenticated
using (owner_id=auth.uid() or public.ktak_role(room_id)='commander')
with check (public.ktak_role(room_id) in ('commander','tactical','recon'));
drop policy if exists "ktak map delete" on public.ktak_map_items;
create policy "ktak map delete" on public.ktak_map_items for delete to authenticated
using (owner_id=auth.uid() or public.ktak_role(room_id)='commander');

drop policy if exists "ktak board settings read" on public.ktak_board_settings;
create policy "ktak board settings read" on public.ktak_board_settings for select to authenticated
using (public.ktak_is_member(room_id));
drop policy if exists "ktak board settings update" on public.ktak_board_settings;
create policy "ktak board settings update" on public.ktak_board_settings for update to authenticated
using (public.ktak_role(room_id) in ('commander','tactical','recon'))
with check (public.ktak_role(room_id) in ('commander','tactical','recon'));

drop policy if exists "ktak board pages read" on public.ktak_board_pages;
create policy "ktak board pages read" on public.ktak_board_pages for select to authenticated
using (public.ktak_is_member(room_id));
drop policy if exists "ktak board pages insert" on public.ktak_board_pages;
create policy "ktak board pages insert" on public.ktak_board_pages for insert to authenticated
with check (public.ktak_role(room_id) in ('commander','tactical','recon'));
drop policy if exists "ktak board pages update" on public.ktak_board_pages;
create policy "ktak board pages update" on public.ktak_board_pages for update to authenticated
using (public.ktak_role(room_id) in ('commander','tactical','recon'))
with check (public.ktak_role(room_id) in ('commander','tactical','recon'));
drop policy if exists "ktak board pages delete" on public.ktak_board_pages;
create policy "ktak board pages delete" on public.ktak_board_pages for delete to authenticated
using (public.ktak_role(room_id) in ('commander','tactical','recon'));

drop policy if exists "ktak board objects read" on public.ktak_board_objects;
create policy "ktak board objects read" on public.ktak_board_objects for select to authenticated
using (public.ktak_is_member(room_id));
drop policy if exists "ktak board objects insert" on public.ktak_board_objects;
create policy "ktak board objects insert" on public.ktak_board_objects for insert to authenticated
with check (
  public.ktak_role(room_id) in ('commander','tactical','recon')
  and (owner_id=auth.uid() or public.ktak_role(room_id)='commander')
);
drop policy if exists "ktak board objects update" on public.ktak_board_objects;
create policy "ktak board objects update" on public.ktak_board_objects for update to authenticated
using (owner_id=auth.uid() or public.ktak_role(room_id)='commander')
with check (public.ktak_role(room_id) in ('commander','tactical','recon'));
drop policy if exists "ktak board objects delete" on public.ktak_board_objects;
create policy "ktak board objects delete" on public.ktak_board_objects for delete to authenticated
using (owner_id=auth.uid() or public.ktak_role(room_id)='commander');

drop policy if exists "ktak chat read" on public.ktak_chat_messages;
create policy "ktak chat read" on public.ktak_chat_messages for select to authenticated
using (public.ktak_is_member(room_id));
drop policy if exists "ktak chat insert" on public.ktak_chat_messages;
create policy "ktak chat insert" on public.ktak_chat_messages for insert to authenticated
with check (
  sender_id=auth.uid()
  and public.ktak_role(room_id) in ('commander','tactical','recon')
);
drop policy if exists "ktak chat delete" on public.ktak_chat_messages;
create policy "ktak chat delete" on public.ktak_chat_messages for delete to authenticated
using (sender_id=auth.uid() or public.ktak_role(room_id)='commander');

-- Direct table privileges. Room creation/join/role updates are RPC-only.
revoke all on public.ktak_rooms,public.ktak_room_members from anon,authenticated;
grant select on public.ktak_rooms,public.ktak_room_members to authenticated;
grant select,update on public.ktak_brief to authenticated;
grant select,insert,update,delete on public.ktak_map_items to authenticated;
grant select,update on public.ktak_board_settings to authenticated;
grant select,insert,update,delete on public.ktak_board_pages,public.ktak_board_objects to authenticated;
grant select,insert,delete on public.ktak_chat_messages to authenticated;

revoke all on function public.ktak_create_room(text,text,text) from public;
revoke all on function public.ktak_join_room(text,text,text,text) from public;
revoke all on function public.ktak_set_member_role(uuid,uuid,text) from public;
grant execute on function public.ktak_create_room(text,text,text) to authenticated;
grant execute on function public.ktak_join_room(text,text,text,text) to authenticated;
grant execute on function public.ktak_set_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.ktak_role(uuid),public.ktak_is_member(uuid),public.ktak_role_text(text) to authenticated;

-- ---------- Private chat photo bucket ----------
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('ktak-chat','ktak-chat',false,6291456,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update
set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "ktak chat photo read" on storage.objects;
create policy "ktak chat photo read" on storage.objects for select to authenticated
using (
  bucket_id='ktak-chat'
  and public.ktak_role_text((storage.foldername(name))[1]) is not null
);

drop policy if exists "ktak chat photo upload" on storage.objects;
create policy "ktak chat photo upload" on storage.objects for insert to authenticated
with check (
  bucket_id='ktak-chat'
  and (storage.foldername(name))[2]=auth.uid()::text
  and public.ktak_role_text((storage.foldername(name))[1]) in ('commander','tactical','recon')
);

drop policy if exists "ktak chat photo delete" on storage.objects;
create policy "ktak chat photo delete" on storage.objects for delete to authenticated
using (
  bucket_id='ktak-chat'
  and public.ktak_role_text((storage.foldername(name))[1]) is not null
  and (
    (storage.foldername(name))[2]=auth.uid()::text
    or public.ktak_role_text((storage.foldername(name))[1])='commander'
  )
);

-- ---------- Realtime ----------
do $$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_room_members')
    then alter publication supabase_realtime add table public.ktak_room_members; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_brief')
    then alter publication supabase_realtime add table public.ktak_brief; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_map_items')
    then alter publication supabase_realtime add table public.ktak_map_items; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_board_settings')
    then alter publication supabase_realtime add table public.ktak_board_settings; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_board_pages')
    then alter publication supabase_realtime add table public.ktak_board_pages; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_board_objects')
    then alter publication supabase_realtime add table public.ktak_board_objects; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='ktak_chat_messages')
    then alter publication supabase_realtime add table public.ktak_chat_messages; end if;
end $$;
