-- 0001_init.sql
-- Initial schema for World Trading Game (Postgres / Supabase)

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- NOTE: Monetary amounts are stored as integer cents (BIGINT) to avoid floating point issues.

-- Games
CREATE TABLE IF NOT EXISTS games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  config jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Players
-- If using Supabase Auth, player.user_id can reference auth.users(id)
CREATE TABLE IF NOT EXISTS players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid, -- optional, link to auth.users
  display_name text,
  avatar_url text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Countries
CREATE TABLE IF NOT EXISTS countries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE,
  name text NOT NULL,
  code text,
  owner_player_id uuid REFERENCES players(id),
  population bigint DEFAULT 0,
  resources jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Building types
CREATE TABLE IF NOT EXISTS building_types (
  id serial PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  base_cost bigint NOT NULL, -- stored in cents
  base_income bigint DEFAULT 0, -- income per tick in cents
  maintenance_cost bigint DEFAULT 0, -- per tick in cents
  max_level integer DEFAULT 1,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Country buildings (instances)
CREATE TABLE IF NOT EXISTS country_buildings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id uuid REFERENCES countries(id) ON DELETE CASCADE,
  building_type_id integer REFERENCES building_types(id) ON DELETE RESTRICT,
  level integer NOT NULL DEFAULT 1,
  count integer NOT NULL DEFAULT 1,
  installed_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb
);

-- Wallets (one per player per currency optional)
CREATE TABLE IF NOT EXISTS wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  currency text NOT NULL DEFAULT 'USD',
  balance bigint NOT NULL DEFAULT 0, -- stored in cents
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id, currency)
);

-- Wallet transactions (audit log)
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid REFERENCES wallets(id) ON DELETE CASCADE,
  amount bigint NOT NULL, -- positive for credit to wallet, negative for debit
  balance_before bigint NOT NULL,
  balance_after bigint NOT NULL,
  event_type text NOT NULL,
  reference_id uuid, -- optional link to related record (bid, listing, purchase...)
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);

-- Country listings (sell a country)
CREATE TABLE IF NOT EXISTS country_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id uuid REFERENCES countries(id) ON DELETE CASCADE,
  seller_player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  price bigint NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  status text NOT NULL DEFAULT 'open', -- open, sold, cancelled
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Bids for listings
CREATE TABLE IF NOT EXISTS bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES country_listings(id) ON DELETE CASCADE,
  bidder_player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  amount bigint NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  status text NOT NULL DEFAULT 'pending', -- pending, accepted, rejected
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bids_listing_id ON bids(listing_id);

-- Income records (periodic/in-game income credited to players)
CREATE TABLE IF NOT EXISTS income_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  amount bigint NOT NULL,
  source text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Events and participation
CREATE TABLE IF NOT EXISTS events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  starts_at timestamptz,
  ends_at timestamptz,
  payload jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_participation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  score bigint DEFAULT 0,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_participation_event ON event_participation(event_id);

-- External currency transactions (exchanges, purchases via payment providers)
CREATE TABLE IF NOT EXISTS external_currency_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  provider text NOT NULL,
  provider_tx_id text,
  amount bigint NOT NULL,
  currency text NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending, completed, failed
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Leaderboard snapshots
CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE,
  rankings jsonb NOT NULL, -- array of {player_id, score, rank}
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  read boolean NOT NULL DEFAULT false,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_player_id ON notifications(player_id);

-- Admin actions / audit
CREATE TABLE IF NOT EXISTS admin_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid, -- reference to auth.users if desired
  action_type text NOT NULL,
  target_table text,
  target_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure updated_at is set automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers for tables that have updated_at
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_games_updated_at') THEN
    CREATE TRIGGER trg_games_updated_at BEFORE UPDATE ON games FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_players_updated_at') THEN
    CREATE TRIGGER trg_players_updated_at BEFORE UPDATE ON players FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_countries_updated_at') THEN
    CREATE TRIGGER trg_countries_updated_at BEFORE UPDATE ON countries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_country_buildings_updated_at') THEN
    CREATE TRIGGER trg_country_buildings_updated_at BEFORE UPDATE ON country_buildings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_country_listings_updated_at') THEN
    CREATE TRIGGER trg_country_listings_updated_at BEFORE UPDATE ON country_listings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
END;
$$;

-- Atomic wallet transfer function
CREATE OR REPLACE FUNCTION transfer_between_wallets(
  from_wallet uuid,
  to_wallet uuid,
  amount bigint,
  event_type text,
  reference_id uuid DEFAULT NULL,
  meta jsonb DEFAULT '{}'::jsonb
) RETURNS void AS $$
DECLARE
  bal_from bigint;
  bal_to bigint;
BEGIN
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be > 0';
  END IF;

  -- lock both wallet rows in a stable order to avoid deadlocks
  IF from_wallet < to_wallet THEN
    SELECT balance INTO bal_from FROM wallets WHERE id = from_wallet FOR UPDATE;
    SELECT balance INTO bal_to FROM wallets WHERE id = to_wallet FOR UPDATE;
  ELSE
    SELECT balance INTO bal_to FROM wallets WHERE id = to_wallet FOR UPDATE;
    SELECT balance INTO bal_from FROM wallets WHERE id = from_wallet FOR UPDATE;
  END IF;

  IF bal_from IS NULL OR bal_to IS NULL THEN
    RAISE EXCEPTION 'wallet not found';
  END IF;

  IF bal_from < amount THEN
    RAISE EXCEPTION 'insufficient_funds';
  END IF;

  -- update balances
  UPDATE wallets SET balance = balance - amount, updated_at = now() WHERE id = from_wallet;
  UPDATE wallets SET balance = balance + amount, updated_at = now() WHERE id = to_wallet;

  -- insert transaction records
  INSERT INTO wallet_transactions (wallet_id, amount, balance_before, balance_after, event_type, reference_id, metadata)
    VALUES (from_wallet, -amount, bal_from, bal_from - amount, event_type, reference_id, meta);

  INSERT INTO wallet_transactions (wallet_id, amount, balance_before, balance_after, event_type, reference_id, metadata)
    VALUES (to_wallet, amount, bal_to, bal_to + amount, event_type, reference_id, meta);
END;
$$ LANGUAGE plpgsql;

-- Row Level Security (templates)
-- Enable RLS where appropriate and create example policies. Review and tighten policies for your app.

ALTER TABLE IF EXISTS wallets ENABLE ROW LEVEL SECURITY;
-- Ensure no overly-permissive policies remain; create more-specific policies in migration 0002
DROP POLICY IF EXISTS wallets_owner_policy ON wallets;

ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;
-- Drop existing permissive policy; a select-only policy is created in migration 0002
DROP POLICY IF EXISTS notifications_owner_policy ON notifications;

ALTER TABLE IF EXISTS players ENABLE ROW LEVEL SECURITY;
-- Drop any permissive policy; migration 0002 creates a select-only players policy
DROP POLICY IF EXISTS players_self ON players;

-- Additional recommended indexes
CREATE INDEX IF NOT EXISTS idx_wallets_player_id ON wallets(player_id);
CREATE INDEX IF NOT EXISTS idx_countries_game_id ON countries(game_id);
CREATE INDEX IF NOT EXISTS idx_country_listings_country_id ON country_listings(country_id);

-- End of migration
