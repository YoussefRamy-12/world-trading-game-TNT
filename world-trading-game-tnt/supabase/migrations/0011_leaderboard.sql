-- 0011_leaderboard.sql
-- Leaderboard snapshot functions: compute net worth and create leaderboard snapshots

-- compute_net_worths: returns player_id and net_worth (in cents) for players in a game.
-- Net worth is currently defined as: sum of USD wallet balances + sum of country values for countries in the game.
CREATE OR REPLACE FUNCTION compute_net_worths(p_game uuid) RETURNS TABLE(player_id uuid, cash bigint, country_value bigint, net_worth bigint) AS $$
BEGIN
  RETURN QUERY
  WITH players_with_cash AS (
    SELECT player_id, SUM(balance) AS cash
    FROM wallets
    WHERE currency = 'USD'
    GROUP BY player_id
  ), players_with_countries AS (
    SELECT c.owner_player_id AS player_id, SUM(country_value(c.id)) AS country_value
    FROM countries c
    WHERE c.game_id = p_game
    GROUP BY c.owner_player_id
  ), all_players AS (
    SELECT COALESCE(pc.player_id, pw.player_id, wc.player_id) AS player_id
    FROM players pw
    LEFT JOIN players_with_countries pc ON pc.player_id = pw.id
    LEFT JOIN players_with_cash wc ON wc.player_id = pw.id
    WHERE pc.player_id IS NOT NULL OR wc.player_id IS NOT NULL
  )
  SELECT
    ap.player_id,
    COALESCE(wc.cash, 0) AS cash,
    COALESCE(pc.country_value, 0) AS country_value,
    COALESCE(wc.cash, 0) + COALESCE(pc.country_value, 0) AS net_worth
  FROM all_players ap
  LEFT JOIN players_with_cash wc ON wc.player_id = ap.player_id
  LEFT JOIN players_with_countries pc ON pc.player_id = ap.player_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- create_leaderboard_snapshot: computes net worths for a game, ranks players, and inserts a snapshot row.
-- Returns the snapshot id.
CREATE OR REPLACE FUNCTION create_leaderboard_snapshot(p_game uuid) RETURNS uuid AS $$
DECLARE
  snapshot_id uuid := gen_random_uuid();
  ranked jsonb;
BEGIN
  -- Compute ranked list using compute_net_worths
  WITH nets AS (
    SELECT player_id, net_worth
    FROM compute_net_worths(p_game)
  ), ranked_rows AS (
    SELECT player_id, net_worth, ROW_NUMBER() OVER (ORDER BY net_worth DESC) AS rank
    FROM nets
  )
  SELECT jsonb_agg(jsonb_build_object('player_id', player_id, 'score', net_worth, 'rank', rank) ORDER BY rank) INTO ranked
  FROM ranked_rows;

  -- Insert snapshot (if no players, ranked will be NULL -> insert empty array)
  INSERT INTO leaderboard_snapshots (id, snapshot_at, game_id, rankings, created_at)
    VALUES (snapshot_id, now(), p_game, COALESCE(ranked, '[]'::jsonb), now());

  RETURN snapshot_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_latest_leaderboard_snapshot: returns the most recent leaderboard snapshot for a game
CREATE OR REPLACE FUNCTION get_latest_leaderboard_snapshot(p_game uuid) RETURNS jsonb AS $$
DECLARE
  s RECORD;
BEGIN
  SELECT * INTO s FROM leaderboard_snapshots WHERE game_id = p_game ORDER BY snapshot_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('game_id', p_game, 'rankings', '[]'::jsonb, 'snapshot_at', NULL);
  END IF;
  RETURN jsonb_build_object('id', s.id, 'snapshot_at', s.snapshot_at, 'game_id', s.game_id, 'rankings', s.rankings);
END;
$$ LANGUAGE plpgsql STABLE;

-- End of migration
