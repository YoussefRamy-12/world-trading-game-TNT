-- 0005_player_registration.sql
-- Player registration, joining games, and admin external funds

-- Create game_players table to track players in games
CREATE TABLE IF NOT EXISTS game_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE,
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active', -- active, left, banned
  metadata jsonb DEFAULT '{}'::jsonb
);

-- RLS: allow players to see their own game_player rows; admins can see all
ALTER TABLE IF EXISTS game_players ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS game_players_select_policy ON game_players;
CREATE POLICY game_players_select_policy ON game_players
  FOR SELECT USING (player_id = auth.uid()::uuid OR EXISTS (SELECT 1 FROM players p WHERE p.id = auth.uid()::uuid AND p.is_admin = true));

-- register_player: creates a player row for the calling auth user if not exists
CREATE OR REPLACE FUNCTION register_player(p_display_name text DEFAULT NULL, p_avatar_url text DEFAULT NULL) RETURNS uuid AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  p_id uuid;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT id INTO p_id FROM players WHERE user_id = caller LIMIT 1;
  IF p_id IS NOT NULL THEN
    RETURN p_id; -- already registered
  END IF;

  INSERT INTO players (id, user_id, display_name, avatar_url, created_at, updated_at)
    VALUES (gen_random_uuid(), caller, COALESCE(p_display_name, ''), COALESCE(p_avatar_url, ''), now(), now()) RETURNING id INTO p_id;

  -- create a default wallet for the player in USD
  INSERT INTO wallets (id, player_id, currency, balance, created_at, updated_at)
    VALUES (gen_random_uuid(), p_id, 'USD', 0, now(), now())
    ON CONFLICT (player_id, currency) DO NOTHING;

  RETURN p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- join_game: player joins a game, receives starting balance from treasury (config driven)
CREATE OR REPLACE FUNCTION join_game(p_game uuid) RETURNS uuid AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  p_id uuid;
  game_cfg jsonb;
  starting_balance bigint := 100000; -- default 1000.00 USD in cents
  player_wallet uuid;
  treasury uuid;
  gp_id uuid;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT id INTO p_id FROM players WHERE user_id = caller LIMIT 1;
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'player_not_registered';
  END IF;

  SELECT config INTO game_cfg FROM games WHERE id = p_game LIMIT 1;
  IF game_cfg IS NOT NULL AND (game_cfg ->> 'starting_balance') IS NOT NULL THEN
    starting_balance := (game_cfg ->> 'starting_balance')::bigint;
  END IF;

  -- create game_players row if missing
  SELECT id INTO gp_id FROM game_players WHERE game_id = p_game AND player_id = p_id LIMIT 1;
  IF gp_id IS NOT NULL THEN
    RETURN gp_id;
  END IF;

  -- ensure player's USD wallet exists
  BEGIN
    SELECT id INTO player_wallet FROM wallets WHERE player_id = p_id AND currency = 'USD' LIMIT 1;
    IF player_wallet IS NULL THEN
      INSERT INTO wallets (id, player_id, currency, balance, created_at, updated_at)
        VALUES (gen_random_uuid(), p_id, 'USD', 0, now(), now()) RETURNING id INTO player_wallet;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'wallet_error';
  END;

  -- ensure treasury
  treasury := ensure_treasury_wallet('USD');

  -- transfer starting balance from treasury to player
  PERFORM transfer_between_wallets(treasury, player_wallet, starting_balance, 'join_game', p_game, jsonb_build_object('player_id', p_id));

  -- insert game_players
  INSERT INTO game_players (id, game_id, player_id, joined_at, status, metadata)
    VALUES (gen_random_uuid(), p_game, p_id, now(), 'active', jsonb_build_object('starting_balance', starting_balance)) RETURNING id INTO gp_id;

  RETURN gp_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- grant_external_funds: admin function to credit a player's wallet (from treasury)
CREATE OR REPLACE FUNCTION grant_external_funds(p_player uuid, p_amount bigint, p_currency text DEFAULT 'USD', p_reference uuid DEFAULT NULL) RETURNS void AS $$
DECLARE
  player_wallet uuid;
  treasury uuid;
BEGIN
  PERFORM _assert_is_admin();

  SELECT id INTO player_wallet FROM wallets WHERE player_id = p_player AND currency = p_currency LIMIT 1;
  IF player_wallet IS NULL THEN
    INSERT INTO wallets (id, player_id, currency, balance, created_at, updated_at)
      VALUES (gen_random_uuid(), p_player, p_currency, 0, now(), now()) RETURNING id INTO player_wallet;
  END IF;

  treasury := ensure_treasury_wallet(p_currency);

  PERFORM transfer_between_wallets(treasury, player_wallet, p_amount, 'external_grant', p_reference, jsonb_build_object('granted_by', auth.uid()::text));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- End of migration
