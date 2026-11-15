-- =====================================================================
-- SOVIS v2.3 업데이트 — 예약·검진관리(resv, visit) 저장 허용 + 권한·백업 반영
-- Supabase > SQL Editor 에 전체 붙여넣고 Run 하세요. (기존 데이터는 그대로 유지)
-- =====================================================================
alter table public.sovis_items drop constraint if exists sovis_items_kind_check;
alter table public.sovis_items add constraint sovis_items_kind_check
  check (kind in ('contracts','oxygen','mail','staff','workday','package','notice','client','billing','exam','bank','expense','expcat','resv','visit'));

create or replace function public.sovis_menu(k text)
returns text language sql immutable as $$
  select case k when 'contracts' then 'contracts' when 'package' then 'contracts' when 'exam' then 'contracts'
                when 'notice' then 'notice' when 'workday' then 'workday' when 'staff' then 'workday'
                when 'oxygen' then 'oxygen' when 'mail' then 'mail'
                when 'billing' then 'billing' when 'client' then 'billing'
                when 'bank' then 'bank' when 'expense' then 'expense' when 'expcat' then 'expense'
                when 'resv' then 'resv' when 'visit' then 'visit' end;
$$;

create or replace function public.sovis_list(token text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare u sovis_users := sovis_auth(token); res jsonb := '{}'::jsonb; k text;
begin
  if u.id is null then return jsonb_build_object('error', 'AUTH'); end if;
  foreach k in array array['contracts','oxygen','mail','staff','workday','package','notice','client','billing','exam','bank','expense','expcat','resv','visit'] loop
    res := res || jsonb_build_object(k, case when sovis_can(u, sovis_menu(k), 'view') then sovis_rows(k) else '[]'::jsonb end);
  end loop;
  return res;
end $$;

create or replace function public.sovis_backup(backup_key text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare k text; d jsonb := '{}'::jsonb;
begin
  if (select count(*) from sovis_fail f where f.who = '#backup' and f.ts > now() - interval '10 minutes') >= 10 then
    return jsonb_build_object('error', 'LOCK');
  end if;
  if backup_key is null or backup_key is distinct from (select value from sovis_config where key = 'backup_key') then
    insert into sovis_fail(who) values ('#backup');
    return jsonb_build_object('error', 'AUTH');
  end if;
  foreach k in array array['contracts','package','exam','client','billing','resv','visit','bank','expense','expcat','notice','workday','staff','oxygen','mail'] loop
    d := d || jsonb_build_object(k, sovis_rows(k));
  end loop;
  return jsonb_build_object('app', 'SOVIS', 'exportedAt', now(), 'data', d,
    'users', coalesce((select jsonb_agg(sovis_user_json(x) order by x.is_admin desc, x.email) from sovis_users x), '[]'::jsonb));
end $$;

revoke execute on function public.sovis_menu(text) from public, anon, authenticated;
revoke execute on function public.sovis_list(text), public.sovis_backup(text) from public, authenticated;
grant execute on function public.sovis_list(text), public.sovis_backup(text) to anon;
