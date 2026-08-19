-- 0012_realtime_events.sql
-- Realtime events table and triggers to emit game events for Supabase Realtime subscriptions

-- Realtime events table: clients can subscribe to this table (filter by game_id or payload)
CREATE TABLE IF NOT EXISTS realtime_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid,
  event_type text NOT NULL,
  payload jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_realtime_events_game_id_created_at ON realtime_events(game_id, created_at);

-- Helper function to safely get game_id from a country_id (returns NULL if not found)
CREATE OR REPLACE FUNCTION _get_game_id_from_country(p_country uuid) RETURNS uuid AS $$
DECLARE
  g uuid;
BEGIN
  SELECT game_id INTO g FROM countries WHERE id = p_country LIMIT 1;
  RETURN g;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger function for country_listings (list created, status changed)
CREATE OR REPLACE FUNCTION trg_realtime_country_listings() RETURNS trigger AS $$
DECLARE
  gid uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    gid := _get_game_id_from_country(NEW.country_id);
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), gid, 'country_listed', jsonb_build_object('listing', to_jsonb(NEW)), now());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    gid := _get_game_id_from_country(NEW.country_id);
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), gid, 'country_listing_status_changed', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_country_listings_trigger ON country_listings;
CREATE TRIGGER realtime_country_listings_trigger
  AFTER INSERT OR UPDATE ON country_listings
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_country_listings();

-- Trigger function for countries (ownership changes -> country_purchased)
CREATE OR REPLACE FUNCTION trg_realtime_countries() RETURNS trigger AS $$
DECLARE
  gid uuid := NEW.game_id;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.owner_player_id IS DISTINCT FROM NEW.owner_player_id THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), gid, 'country_purchased', jsonb_build_object('country_id', NEW.id, 'old_owner', OLD.owner_player_id, 'new_owner', NEW.owner_player_id), now());
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_countries_trigger ON countries;
CREATE TRIGGER realtime_countries_trigger
  AFTER UPDATE ON countries
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_countries();

-- Trigger for bids (created, status changes)
CREATE OR REPLACE FUNCTION trg_realtime_bids() RETURNS trigger AS $$
DECLARE
  gid uuid;
  listing_game uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT _get_game_id_from_country(cl.country_id) INTO listing_game FROM country_listings cl WHERE cl.id = NEW.listing_id LIMIT 1;
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), listing_game, 'bid_created', jsonb_build_object('bid', to_jsonb(NEW)), now());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    SELECT _get_game_id_from_country(cl.country_id) INTO listing_game FROM country_listings cl WHERE cl.id = NEW.listing_id LIMIT 1;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      IF NEW.status = 'accepted' THEN
        INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
          VALUES (gen_random_uuid(), listing_game, 'bid_accepted', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
      ELSIF NEW.status IN ('cancelled','rejected') THEN
        INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
          VALUES (gen_random_uuid(), listing_game, 'bid_cancelled', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
      ELSE
        INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
          VALUES (gen_random_uuid(), listing_game, 'bid_status_changed', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
      END IF;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_bids_trigger ON bids;
CREATE TRIGGER realtime_bids_trigger
  AFTER INSERT OR UPDATE ON bids
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_bids();

-- Trigger for country_buildings (upgrades/level changes)
CREATE OR REPLACE FUNCTION trg_realtime_country_buildings() RETURNS trigger AS $$
DECLARE
  gid uuid;
BEGIN
  SELECT _get_game_id_from_country(cb.country_id) INTO gid FROM country_buildings cb WHERE cb.id = COALESCE(NEW.id, OLD.id) LIMIT 1;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.level IS DISTINCT FROM OLD.level OR NEW.count IS DISTINCT FROM OLD.count THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), gid, 'country_upgraded', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_country_buildings_trigger ON country_buildings;
CREATE TRIGGER realtime_country_buildings_trigger
  AFTER UPDATE ON country_buildings
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_country_buildings();

-- Trigger for wallets (balance updates)
CREATE OR REPLACE FUNCTION trg_realtime_wallets() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.balance IS DISTINCT FROM OLD.balance THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), NULL, 'wallet_updated', jsonb_build_object('wallet_id', NEW.id, 'player_id', NEW.player_id, 'balance_before', OLD.balance, 'balance_after', NEW.balance), now());
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_wallets_trigger ON wallets;
CREATE TRIGGER realtime_wallets_trigger
  AFTER UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_wallets();

-- Trigger for income_records (credits)
CREATE OR REPLACE FUNCTION trg_realtime_income_records() RETURNS trigger AS $$
DECLARE
  gid uuid := (SELECT game_id FROM games g WHERE g.id = (SELECT game_id FROM countries WHERE owner_player_id = NEW.player_id LIMIT 1) LIMIT 1);
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), gid, 'income_received', jsonb_build_object('player_id', NEW.player_id, 'amount', NEW.amount, 'source', NEW.source, 'metadata', NEW.metadata), now());
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_income_records_trigger ON income_records;
CREATE TRIGGER realtime_income_records_trigger
  AFTER INSERT ON income_records
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_income_records();

-- Trigger for players (join/leave)
CREATE OR REPLACE FUNCTION trg_realtime_players() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), NULL, 'player_joined', jsonb_build_object('player', to_jsonb(NEW)), now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), NULL, 'player_left', jsonb_build_object('player', to_jsonb(OLD)), now());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_players_trigger ON players;
CREATE TRIGGER realtime_players_trigger
  AFTER INSERT OR DELETE ON players
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_players();

-- Trigger for leaderboard_snapshots (leaderboard updates)
CREATE OR REPLACE FUNCTION trg_realtime_leaderboard_snapshots() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), NEW.game_id, 'leaderboard_updated', jsonb_build_object('snapshot_id', NEW.id, 'rankings', NEW.rankings), now());
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_leaderboard_snapshots_trigger ON leaderboard_snapshots;
CREATE TRIGGER realtime_leaderboard_snapshots_trigger
  AFTER INSERT ON leaderboard_snapshots
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_leaderboard_snapshots();

-- Trigger for events (event created/started/ended)
CREATE OR REPLACE FUNCTION trg_realtime_events_table() RETURNS trigger AS $$
DECLARE
  gid uuid := NULL;
BEGIN
  -- events table has starts_at/ends_at and optional payload
  IF TG_OP = 'INSERT' THEN
    INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
      VALUES (gen_random_uuid(), gid, 'event_created', jsonb_build_object('event', to_jsonb(NEW)), now());
    -- if starts_at is in the past, also emit started
    IF NEW.starts_at IS NOT NULL AND NEW.starts_at <= now() THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), gid, 'event_started', jsonb_build_object('event', to_jsonb(NEW)), now());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- started
    IF NEW.starts_at IS DISTINCT FROM OLD.starts_at AND NEW.starts_at IS NOT NULL AND NEW.starts_at <= now() THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), gid, 'event_started', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
    END IF;
    -- ended
    IF NEW.ends_at IS DISTINCT FROM OLD.ends_at AND NEW.ends_at IS NOT NULL AND NEW.ends_at <= now() THEN
      INSERT INTO realtime_events (id, game_id, event_type, payload, created_at)
        VALUES (gen_random_uuid(), gid, 'event_ended', jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), now());
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS realtime_events_table_trigger ON events;
CREATE TRIGGER realtime_events_table_trigger
  AFTER INSERT OR UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION trg_realtime_events_table();

-- End of migration
