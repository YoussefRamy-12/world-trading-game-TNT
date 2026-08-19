-- 0004_game_lifecycle.sql
-- Add game lifecycle columns, admin flag and secure lifecycle functions

-- Create enum type for game state
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'game_state') THEN
    CREATE TYPE game_state AS ENUM ('draft','ready','running','paused','finished');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Add lifecycle columns to games
ALTER TABLE IF EXISTS games
  ADD COLUMN IF NOT EXISTS state game_state NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS paused_at timestamptz,
  ADD COLUMN IF NOT EXISTS finished_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_tick_at timestamptz,
  ADD COLUMN IF NOT EXISTS current_tick integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tick_interval_seconds integer NOT NULL DEFAULT 3600;

-- Add is_admin flag to players
ALTER TABLE IF EXISTS players ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- Enable RLS on games and allow SELECTs; disallow client-side writes by omitting write policies
ALTER TABLE IF EXISTS games ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS games_select_policy ON games;
CREATE POLICY games_select_policy ON games
  FOR SELECT USING (true);

-- Lifecycle transition functions. SECURITY DEFINER: owned by a privileged role after deployment.

-- Helper: ensure caller is admin (either auth.uid() is an admin player or the call is made by a DB owner/service role where auth.uid() is NULL)
CREATE OR REPLACE FUNCTION _assert_is_admin() RETURNS void AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  is_admin boolean := false;
BEGIN
  IF caller IS NULL THEN
    -- called by service role or direct DB owner connection; allow
    RETURN;
  END IF;

  SELECT p.is_admin INTO is_admin FROM players p WHERE p.id = caller;
  IF NOT is_admin THEN
    RAISE EXCEPTION 'not_admin';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- set_game_ready: DRAFT -> READY
CREATE OR REPLACE FUNCTION set_game_ready(p_game uuid) RETURNS void AS $$
BEGIN
  PERFORM _assert_is_admin();
  UPDATE games SET state = 'ready', updated_at = now() WHERE id = p_game AND state = 'draft';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state_transition';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- start_game: READY -> RUNNING (or RESUME from PAUSED also uses resume_game)
CREATE OR REPLACE FUNCTION start_game(p_game uuid) RETURNS void AS $$
BEGIN
  PERFORM _assert_is_admin();
  UPDATE games SET state = 'running', started_at = CASE WHEN started_at IS NULL THEN now() ELSE started_at END, last_tick_at = now(), updated_at = now() WHERE id = p_game AND state = 'ready';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state_transition';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- pause_game: RUNNING -> PAUSED
CREATE OR REPLACE FUNCTION pause_game(p_game uuid) RETURNS void AS $$
BEGIN
  PERFORM _assert_is_admin();
  UPDATE games SET state = 'paused', paused_at = now(), updated_at = now() WHERE id = p_game AND state = 'running';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state_transition';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- resume_game: PAUSED -> RUNNING (preserve started_at)
CREATE OR REPLACE FUNCTION resume_game(p_game uuid) RETURNS void AS $$
BEGIN
  PERFORM _assert_is_admin();
  UPDATE games SET state = 'running', last_tick_at = now(), updated_at = now() WHERE id = p_game AND state = 'paused';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state_transition';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- finish_game: any -> FINISHED (but typically from RUNNING/PAUSED)
CREATE OR REPLACE FUNCTION finish_game(p_game uuid) RETURNS void AS $$
BEGIN
  PERFORM _assert_is_admin();
  UPDATE games SET state = 'finished', finished_at = now(), updated_at = now() WHERE id = p_game AND state != 'finished';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state_transition';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- advance_tick: increments current_tick when running; intended for scheduler
CREATE OR REPLACE FUNCTION advance_tick(p_game uuid) RETURNS integer AS $$
DECLARE
  new_tick integer;
BEGIN
  PERFORM _assert_is_admin();
  UPDATE games SET current_tick = current_tick + 1, last_tick_at = now(), updated_at = now() WHERE id = p_game AND state = 'running' RETURNING current_tick INTO new_tick;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'game_not_running';
  END IF;
  RETURN new_tick;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: After applying this migration, set function owners to a privileged role (postgres) so SECURITY DEFINER functions run with expected privileges.

-- End of migration
