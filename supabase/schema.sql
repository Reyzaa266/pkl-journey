create extension if not exists pgcrypto;
create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', email text not null default '',
 school text default '', class_name text default '', company text default '',
 mentor text default '', role text not null default 'student' check(role in('student','teacher','admin')),
 created_at timestamptz default now(),updated_at timestamptz default now());
create table if not exists public.journals(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 journal_date date not null,title text not null,activity text not null,result text default '',
 obstacles text default '',solution text default '',status text not null default 'draft'
 check(status in('draft','submitted','approved','revision')),teacher_note text default '',
 created_at timestamptz default now(),updated_at timestamptz default now());
create unique index if not exists journals_user_date on public.journals(user_id,journal_date);
create table if not exists public.attendance(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 attendance_date date not null,status text not null default 'present'
 check(status in('present','sick','permission','absent')),note text default '',created_at timestamptz default now());
create unique index if not exists attendance_user_date on public.attendance(user_id,attendance_date);
create table if not exists public.documents(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 file_name text not null,file_path text not null,file_url text,caption text default '',created_at timestamptz default now());
create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,email,full_name) values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'full_name','')); return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.new_profile();
alter table public.profiles enable row level security; alter table public.journals enable row level security;
alter table public.attendance enable row level security; alter table public.documents enable row level security;
create policy "profile self" on public.profiles for all using(auth.uid()=id) with check(auth.uid()=id);
create policy "journal access" on public.journals for select using(auth.uid()=user_id or exists(select 1 from profiles where id=auth.uid() and role in('teacher','admin')));
create policy "journal add" on public.journals for insert with check(auth.uid()=user_id);
create policy "journal edit" on public.journals for update using(auth.uid()=user_id or exists(select 1 from profiles where id=auth.uid() and role in('teacher','admin')));
create policy "journal del" on public.journals for delete using(auth.uid()=user_id or exists(select 1 from profiles where id=auth.uid() and role in('teacher','admin')));
create policy "attendance self" on public.attendance for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "documents self" on public.documents for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
insert into storage.buckets(id,name,public) values('pkl-documents','pkl-documents',true) on conflict(id) do nothing;
create policy "storage upload" on storage.objects for insert to authenticated with check(bucket_id='pkl-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "storage read" on storage.objects for select to public using(bucket_id='pkl-documents');
create policy "storage delete" on storage.objects for delete to authenticated using(bucket_id='pkl-documents' and (storage.foldername(name))[1]=auth.uid()::text);
