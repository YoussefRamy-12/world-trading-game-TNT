-- 0003_add_countries_metadata.sql
-- Add missing metadata column to countries and recreate RLS policy that depends on it

-- Add metadata column if it doesn't exist (safe for existing DBs)
ALTER TABLE IF EXISTS countries ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Ensure RLS enabled and recreate the select policy using metadata->>'public'
ALTER TABLE IF EXISTS countries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS countries_select_policy ON countries;
CREATE POLICY countries_select_policy ON countries
  FOR SELECT USING (
    (metadata->> 'public' = 'true') OR (owner_player_id = auth.uid()::uuid)
  );

-- Optional: index the metadata->>'public' path for faster public lookups
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE tablename = 'countries' AND indexname = 'idx_countries_public_flag'
  ) THEN
    CREATE INDEX idx_countries_public_flag ON countries ((metadata->> 'public'));
  END IF;
END;
$$ LANGUAGE plpgsql;
