-- ロレポチ（1期生）：リアルタイム同期＋店舗買付の保存修正
-- Supabase ダッシュボード → SQL Editor → New query にこの全文を貼って Run
-- （何回実行しても安全：すでに反映済みの場合はスキップ／同型変更されます）

-- 1) store_purchases.id を BIGINT に変更
--    （id は Date.now()＝約1.75兆を採番。INTEGER 上限21億超のため保存に失敗していた）
ALTER TABLE store_purchases ALTER COLUMN id TYPE BIGINT;

-- 2) リアルタイム対象テーブルを supabase_realtime publication に追加（冪等）
do $$
declare t text;
begin
  foreach t in array array[
    'weekly_inputs',
    'members',
    'win_history',
    'purchase_results',
    'store_purchases'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 確認用：リアルタイム対象になっているテーブル一覧
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
  and tablename in ('weekly_inputs','members','win_history','purchase_results','store_purchases')
order by tablename;
