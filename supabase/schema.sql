-- روجا ستور — مخطط Supabase
-- نفّذ هذا الملف من SQL Editor في مشروع Supabase.
-- القاعدة الأساسية: التطبيق لا يعرف كلمة مرور الأدمن ولا أي مفتاح سري؛
-- الخادم وحده يمنح صلاحية admin عبر جدول profiles وسياسات RLS.

create extension if not exists pgcrypto;

-- 1) السماح بإيميلات @fatimiyoun.me فقط عند إنشاء حساب في Supabase Auth.
create or replace function public.validate_email_domain()
returns trigger
language plpgsql
as $$
begin
  if new.email is null
     or lower(split_part(new.email, '@', 2)) <> 'fatimiyoun.me' then
    raise exception 'يُسمح فقط بإيميلات @fatimiyoun.me';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_email_domain on auth.users;
create trigger validate_email_domain
before insert on auth.users
for each row execute function public.validate_email_domain();

-- 2) ملف المستخدم: الدور يُخزّن هنا ويُقرأ من الخادم فقط.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'user')
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- دالة آمنة لقراءة الدور بدون تكرار سياسات RLS على profiles.
create or replace function public.is_admin(uid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = uid and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;

drop policy if exists "profiles select self or admin" on public.profiles;
create policy "profiles select self or admin"
on public.profiles for select
using (auth.uid() = id or public.is_admin(auth.uid()));

drop policy if exists "profiles admin update" on public.profiles;
create policy "profiles admin update"
on public.profiles for update
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- 3) الكتالوج: القراءة عامة، والكتابة للأدمن فقط.
create table if not exists public.apps (
  id text primary key,
  name text not null,
  tagline text not null default '',
  description text not null default '',
  category text not null default 'عام',
  version text not null default '',
  size text not null default '',
  icon_url text not null default '',
  apk_url text not null default '',
  package_name text not null default '',
  changelog text not null default '',
  screenshots text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.apps enable row level security;

drop policy if exists "apps public read" on public.apps;
create policy "apps public read"
on public.apps for select
using (true);

drop policy if exists "apps admin write" on public.apps;
create policy "apps admin write"
on public.apps for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- 4) التقييمات: القراءة عامة، والإضافة للمستخدمين المسجّلين، والحذف للأدمن.
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  app_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  author text not null default 'مستخدم',
  rating integer not null check (rating between 1 and 5),
  text text not null default '',
  created_at timestamptz not null default now()
);

alter table public.reviews enable row level security;

drop policy if exists "reviews public read" on public.reviews;
create policy "reviews public read"
on public.reviews for select
using (true);

drop policy if exists "reviews authenticated insert" on public.reviews;
create policy "reviews authenticated insert"
on public.reviews for insert
with check (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "reviews owner or admin delete" on public.reviews;
create policy "reviews owner or admin delete"
on public.reviews for delete
using (auth.uid() = user_id or public.is_admin(auth.uid()));

-- 5) Storage للـ APK: عام للقراءة، والرفع للأدمن فقط.
insert into storage.buckets (id, name, public, file_size_limit)
values ('apks', 'apks', true, 104857600)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit;

drop policy if exists "apks public read" on storage.objects;
create policy "apks public read"
on storage.objects for select
using (bucket_id = 'apks');

drop policy if exists "apks admin write" on storage.objects;
create policy "apks admin write"
on storage.objects for all
using (bucket_id = 'apks' and public.is_admin(auth.uid()))
with check (bucket_id = 'apks' and public.is_admin(auth.uid()));

-- 6) حذف مستخدم من الأدمن فقط (دالة على الخادم، لا مفتاح في التطبيق).
create or replace function public.admin_delete_user(target uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'غير مسموح';
  end if;
  delete from auth.users where id = target;
end;
$$;

revoke all on function public.admin_delete_user(uuid) from public;
grant execute on function public.admin_delete_user(uuid) to authenticated;

-- 7) بعد إنشاء حسابك، امنح نفسك صلاحية الأدمن من SQL Editor:
-- update public.profiles
-- set role = 'admin'
-- where lower(email) = 'yourname@fatimiyoun.me';
--
-- ملاحظة: مفتاح anon Key الذي يُوضع في التطبيق عام بالتصميم.
-- الحماية الحقيقية هي سياسات RLS أعلاه، وليس إخفاء المفتاح.
