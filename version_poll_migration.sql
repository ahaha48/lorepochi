-- ロレポチ（1期生）：リアルタイム同期 → 「データ更新番号」ポーリングへの切り替え
-- Supabase ダッシュボード → SQL Editor → New query に貼って Run
-- 背景：無料プラン Nano のメモリ不足（スワップ）で Disk IO 予算が減るため、Realtime の常時接続をやめる。
--       保存のたびに app_config の __data__ 行の番号をトリガで進め、画面側は60秒ごとの版数確認に相乗りして変化を検知する。
--
-- 実行順序：
--   フェーズA（この節）… 新コードを push する【前】に実行。旧コードには無害。
--   フェーズB（下の節）… 新コードを push し、全員のタブが新版に切り替わった【後】に実行。
-- 何回実行しても安全（冪等）。

-- ============================================================
-- フェーズA：更新番号トリガ＋__data__ 行
-- ============================================================
create or replace function public.bump_data_version() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.app_config set cur_month = coalesce(cur_month,0) + 1 where key = '__data__';
  if not found then
    insert into public.app_config(key, cur_month) values ('__data__', 1)
    on conflict (key) do update set cur_month = coalesce(app_config.cur_month,0) + 1;
  end if;
  return null;
exception when others then
  return null;  -- 番号更新に失敗しても本体の保存は止めない
end $$;

drop trigger if exists trg_bump_data_version on public.members;
create trigger trg_bump_data_version after insert or update or delete on public.members
  for each statement execute function public.bump_data_version();
drop trigger if exists trg_bump_data_version on public.weekly_inputs;
create trigger trg_bump_data_version after insert or update or delete on public.weekly_inputs
  for each statement execute function public.bump_data_version();
drop trigger if exists trg_bump_data_version on public.win_history;
create trigger trg_bump_data_version after insert or update or delete on public.win_history
  for each statement execute function public.bump_data_version();
drop trigger if exists trg_bump_data_version on public.purchase_results;
create trigger trg_bump_data_version after insert or update or delete on public.purchase_results
  for each statement execute function public.bump_data_version();
drop trigger if exists trg_bump_data_version on public.store_purchases;
create trigger trg_bump_data_version after insert or update or delete on public.store_purchases
  for each statement execute function public.bump_data_version();

insert into public.app_config(key, cur_month) values ('__data__', 1) on conflict (key) do nothing;

-- 確認：__guard__ と __data__ の2行、トリガ5本
select key, cur_month from public.app_config where key in ('__guard__','__data__') order by key;
select tgrelid::regclass as table_name, tgname from pg_trigger where tgname = 'trg_bump_data_version' order by 1;

-- ============================================================
-- フェーズB：Realtime の配信対象から外す（push 後・全員の再読み込み後に実行）
-- ============================================================
-- do $$ declare t text; begin
--   foreach t in array array['weekly_inputs','members','win_history','purchase_results','store_purchases'] loop
--     if exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
--       execute format('alter publication supabase_realtime drop table public.%I', t);
--     end if;
--   end loop; end $$;
-- select tablename from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' order by 1;

-- ============================================================
-- ロールバック（元に戻すとき）
-- ============================================================
-- 1) コードを git revert して push するときは、APP_VERSION を DB の __guard__ より大きい値に上げること
--    （上げないと全タブが「古いタブ」判定で保存停止になる）。代替：
--    update public.app_config set cur_month = 20260630 where key = '__guard__';
-- 2) トリガと番号行を削除：
--    drop function if exists public.bump_data_version() cascade;  -- 依存トリガ5本もまとめて削除
--    delete from public.app_config where key = '__data__';
-- 3) Realtime の配信対象を戻す（enable_realtime_lorepochi.sql は ALTER COLUMN を含むので全文は流さない）：
--    do $$ declare t text; begin
--      foreach t in array array['weekly_inputs','members','win_history','purchase_results','store_purchases'] loop
--        if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
--          execute format('alter publication supabase_realtime add table public.%I', t);
--        end if;
--      end loop; end $$;
