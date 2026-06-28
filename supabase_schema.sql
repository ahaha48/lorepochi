-- ================================================================
-- ロレポチ Supabase スキーマ
-- Supabase SQL Editor で全文実行してください
-- ================================================================

-- 1. members テーブル
CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY,
  line_name TEXT,
  name TEXT,
  status TEXT DEFAULT '未当選',
  priority TEXT DEFAULT '1:アクティブ',
  won1 TEXT,
  won2 TEXT,
  won3 TEXT,
  last_active TEXT,
  total_reward INTEGER DEFAULT 0,
  note TEXT DEFAULT '',
  no_purchase BOOLEAN DEFAULT FALSE,
  store_purchase_date TEXT,
  line_user_id TEXT
);

-- 2. weekly_inputs テーブル（WEEKLY オブジェクトを行に変換）
CREATE TABLE IF NOT EXISTS weekly_inputs (
  month INTEGER NOT NULL,
  week INTEGER NOT NULL,
  member_id INTEGER NOT NULL,
  apply INTEGER DEFAULT 0,
  result_ss BOOLEAN DEFAULT FALSE,
  won_date TEXT,
  won_shop TEXT,
  restricted_applied BOOLEAN DEFAULT FALSE,
  restricted_result TEXT,
  PRIMARY KEY (month, week, member_id)
);

-- 3. win_history テーブル
CREATE TABLE IF NOT EXISTS win_history (
  id INTEGER PRIMARY KEY,
  member_id INTEGER,
  line_name TEXT,
  name TEXT,
  won_date TEXT,
  shop TEXT,
  win_num INTEGER,
  month INTEGER,
  week INTEGER,
  is_companion_mode BOOLEAN DEFAULT FALSE,
  visit_date TEXT
);

-- 4. purchase_results テーブル（PURCHASE オブジェクトを行に変換）
CREATE TABLE IF NOT EXISTS purchase_results (
  win_idx INTEGER PRIMARY KEY,
  result TEXT,
  purchase_date TEXT,
  units INTEGER,
  companion TEXT,
  companion_result TEXT,
  companion_units INTEGER,
  note TEXT,
  restriction_memo TEXT
);

-- 5. store_purchases テーブル
-- id は Date.now()（約1.75兆）を採番するため BIGINT 必須（INTEGER だと上限超で保存失敗）
CREATE TABLE IF NOT EXISTS store_purchases (
  id BIGINT PRIMARY KEY,
  member_id INTEGER,
  line_name TEXT,
  name TEXT,
  purchase_date TEXT,
  shop TEXT,
  result TEXT,
  units INTEGER,
  companion TEXT,
  note TEXT
);

-- 6. app_config テーブル（月・週の状態管理）
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  cur_month INTEGER DEFAULT 1,
  cur_week INTEGER DEFAULT 1,
  available_months JSONB DEFAULT '[1]'
);

-- ================================================================
-- RLS（Row Level Security）設定
-- 認証済みユーザー（管理者）のみ全操作可
-- ================================================================
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE win_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- 既存ポリシーを削除してから再作成
DROP POLICY IF EXISTS "Allow authenticated" ON members;
DROP POLICY IF EXISTS "Allow authenticated" ON weekly_inputs;
DROP POLICY IF EXISTS "Allow authenticated" ON win_history;
DROP POLICY IF EXISTS "Allow authenticated" ON purchase_results;
DROP POLICY IF EXISTS "Allow authenticated" ON store_purchases;
DROP POLICY IF EXISTS "Allow authenticated" ON app_config;

CREATE POLICY "Allow authenticated" ON members
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated" ON weekly_inputs
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated" ON win_history
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated" ON purchase_results
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated" ON store_purchases
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated" ON app_config
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ================================================================
-- 初期データ投入（app_config のデフォルト行）
-- ================================================================
INSERT INTO app_config (key, cur_month, cur_week, available_months)
VALUES ('main', 3, 1, '[1,2,3]')
ON CONFLICT (key) DO NOTHING;
