-- =====================================================================
-- SOVIS v1.1 업데이트 — 워킹데이 계획(행정 인원 / 날짜별 근무) 저장 허용
-- Supabase > SQL Editor 에 전체 붙여넣고 Run 한 번만 실행하세요. (기존 데이터는 그대로 유지)
-- =====================================================================
alter table public.sovis_items drop constraint if exists sovis_items_kind_check;
alter table public.sovis_items add constraint sovis_items_kind_check
  check (kind in ('contracts','oxygen','mail','staff','workday'));

create or replace function public.sovis_list(pin text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := sovis_check(pin);
begin
  if r <> 'OK' then return jsonb_build_object('error', r); end if;
  return jsonb_build_object(
    'contracts', sovis_rows('contracts'),
    'oxygen',    sovis_rows('oxygen'),
    'mail',      sovis_rows('mail'),
    'staff',     sovis_rows('staff'),
    'workday',   sovis_rows('workday'));
end $$;

create or replace function public.sovis_save(pin text, kind text, item jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := sovis_check(pin); v_kind text := kind; v_id text;
begin
  if r <> 'OK' then return jsonb_build_object('error', r); end if;
  if v_kind not in ('contracts','oxygen','mail','staff','workday') then return jsonb_build_object('error','잘못된 구분'); end if;
  if length(item::text) > 20000 then return jsonb_build_object('error','내용이 너무 깁니다'); end if;
  v_id := coalesce(nullif(item->>'id',''), substr(md5(random()::text || clock_timestamp()::text), 1, 12));
  insert into sovis_items as t (kind, id, data, updated_at)
  values (v_kind, v_id, item - 'id', now())
  on conflict on constraint sovis_items_pkey
  do update set data = excluded.data, updated_at = now();
  return sovis_rows(v_kind);
end $$;

grant execute on function public.sovis_list(text), public.sovis_save(text, text, jsonb) to anon;
