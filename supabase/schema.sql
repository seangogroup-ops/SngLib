-- =====================================================================
-- SngLib · schema Supabase (chạy 1 lần trong SQL Editor)
-- Gồm: thống kê truy cập, thông báo, liên kết, phân quyền admin
-- =====================================================================

-- ---------- Bảng ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.visits (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  kind        text not null default 'view' check (kind in ('view','search','ping')),
  visitor_id  text not null check (char_length(visitor_id) between 8 and 64),
  session_id  text check (char_length(session_id) <= 64),
  path        text check (char_length(path) <= 200),
  referrer    text check (char_length(referrer) <= 120),
  device      text check (char_length(device) <= 20),
  browser     text check (char_length(browser) <= 30),
  os          text check (char_length(os) <= 30),
  lang        text check (char_length(lang) <= 20),
  tz          text check (char_length(tz) <= 60),
  screen      text check (char_length(screen) <= 20),
  q           text check (char_length(q) <= 200)
);
create index if not exists visits_created_idx on public.visits (created_at desc);
create index if not exists visits_visitor_idx on public.visits (visitor_id);

create table if not exists public.announcements (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  title       text not null check (char_length(title) between 1 and 160),
  body        text check (char_length(body) <= 1000),
  link_url    text check (char_length(link_url) <= 500),
  link_label  text check (char_length(link_label) <= 60),
  level       text not null default 'info' check (level in ('info','warn','success')),
  active      boolean not null default true,
  starts_at   timestamptz,
  ends_at     timestamptz
);

create table if not exists public.links (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  title       text not null check (char_length(title) between 1 and 80),
  url         text not null check (char_length(url) <= 500),
  sort        int not null default 0,
  active      boolean not null default true
);

-- ---------- Hàm kiểm tra admin ----------
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------- RLS ----------
alter table public.admins        enable row level security;
alter table public.visits        enable row level security;
alter table public.announcements enable row level security;
alter table public.links         enable row level security;

drop policy if exists "admins self read"      on public.admins;
drop policy if exists "visits insert"         on public.visits;
drop policy if exists "visits admin read"     on public.visits;
drop policy if exists "visits admin delete"   on public.visits;
drop policy if exists "ann public read"       on public.announcements;
drop policy if exists "ann admin all"         on public.announcements;
drop policy if exists "links public read"     on public.links;
drop policy if exists "links admin all"       on public.links;

create policy "admins self read" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- Ai cũng ghi được lượt truy cập (đã giới hạn độ dài bằng CHECK), chỉ admin mới đọc
create policy "visits insert" on public.visits
  for insert to anon, authenticated with check (true);
create policy "visits admin read" on public.visits
  for select to authenticated using (public.is_admin());
create policy "visits admin delete" on public.visits
  for delete to authenticated using (public.is_admin());

-- Khách chỉ thấy thông báo / liên kết đang bật
create policy "ann public read" on public.announcements
  for select to anon, authenticated
  using (active and (starts_at is null or starts_at <= now())
                and (ends_at   is null or ends_at   >  now()));
create policy "ann admin all" on public.announcements
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "links public read" on public.links
  for select to anon, authenticated using (active);
create policy "links admin all" on public.links
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Admin cần đọc cả bản ghi đang tắt / hết hạn: policy "admin all" đã cho phép (OR với policy public)

-- ---------- Thống kê (chỉ admin gọi được) ----------
create or replace function public.admin_stats(p_days int default 30)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  tzn   constant text := 'Asia/Ho_Chi_Minh';
  days  int := greatest(1, least(coalesce(p_days, 30), 365));
  today date := (now() at time zone tzn)::date;
  start_ts timestamptz := ((today - (days - 1))::timestamp) at time zone tzn;
  today_ts timestamptz := (today::timestamp) at time zone tzn;
  res jsonb;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  with w as (select * from public.visits where created_at >= start_ts)
  select jsonb_build_object(
    'days', days,
    'totals', jsonb_build_object(
      'views',         (select count(*) from w where kind = 'view'),
      'visitors',      (select count(distinct visitor_id) from w),
      'searches',      (select count(*) from w where kind = 'search'),
      'today_views',   (select count(*) from w where kind = 'view' and created_at >= today_ts),
      'today_visitors',(select count(distinct visitor_id) from w where created_at >= today_ts),
      'online',        (select count(distinct visitor_id) from public.visits
                          where created_at >= now() - interval '5 minutes'),
      'new_visitors',  (select count(*) from (
                          select visitor_id from public.visits
                          group by visitor_id having min(created_at) >= start_ts) x)
    ),
    'daily', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'd', to_char(g.d, 'YYYY-MM-DD'),
               'views', coalesce(v.views, 0),
               'visitors', coalesce(v.visitors, 0)) order by g.d), '[]'::jsonb)
      from generate_series((today - (days - 1))::timestamp, today::timestamp, interval '1 day') as g(d)
      left join (
        select (created_at at time zone tzn)::date as dd,
               count(*) filter (where kind = 'view') as views,
               count(distinct visitor_id) as visitors
        from w group by 1
      ) v on v.dd = g.d::date
    ),
    'hourly', (
      select coalesce(jsonb_agg(jsonb_build_object('h', h, 'n', coalesce(c.n, 0)) order by h), '[]'::jsonb)
      from generate_series(0, 23) h
      left join (
        select extract(hour from created_at at time zone tzn)::int as hh, count(*) as n
        from w where kind = 'view' group by 1
      ) c on c.hh = h
    ),
    'queries', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select lower(q) as name, count(*) as n from w
      where kind = 'search' and coalesce(q, '') <> ''
      group by 1 order by n desc, name limit 15) t),
    'referrers', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select coalesce(nullif(referrer, ''), '(truy cập trực tiếp)') as name, count(*) as n from w
      where kind = 'view' group by 1 order by n desc limit 10) t),
    'devices', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select coalesce(nullif(device, ''), '?') as name, count(distinct visitor_id) as n from w
      group by 1 order by n desc limit 6) t),
    'browsers', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select coalesce(nullif(browser, ''), '?') as name, count(distinct visitor_id) as n from w
      group by 1 order by n desc limit 8) t),
    'systems', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select coalesce(nullif(os, ''), '?') as name, count(distinct visitor_id) as n from w
      group by 1 order by n desc limit 8) t),
    'langs', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select coalesce(nullif(lang, ''), '?') as name, count(distinct visitor_id) as n from w
      group by 1 order by n desc limit 8) t),
    'zones', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
      select coalesce(nullif(tz, ''), '?') as name, count(distinct visitor_id) as n from w
      group by 1 order by n desc limit 8) t)
  ) into res;

  return res;
end;
$$;
revoke all on function public.admin_stats(int) from public, anon;
grant execute on function public.admin_stats(int) to authenticated;

-- ---------- Dọn dữ liệu cũ (tùy chọn) ----------
-- delete from public.visits where created_at < now() - interval '400 days';

-- =====================================================================
-- SAU KHI CHẠY XONG:
-- 1) Supabase → Authentication → Users → Add user (email + mật khẩu) → tick "Auto confirm".
-- 2) Authentication → Sign In / Providers → tắt "Allow new users to sign up".
-- 3) Cấp quyền admin cho tài khoản đó (đổi email):
--
--    insert into public.admins (user_id)
--    select id from auth.users where email = 'ban@example.com';
-- =====================================================================
