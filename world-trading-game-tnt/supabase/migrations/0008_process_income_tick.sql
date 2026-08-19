-- 0008_process_income_tick.sql
-- Combine tick advancement with income processing: process_game_tick

-- This function advances the game's tick (ensuring only admins or service-role callers may run it)
-- and then processes income for the game in the same transaction. Returns a JSON object with
-- the new tick and the number of players credited.

CREATE OR REPLACE FUNCTION process_game_tick(p_game uuid) RETURNS jsonb AS $$
DECLARE
  new_tick integer;
  income_count integer;
  rec RECORD;
BEGIN
  -- Reuse admin assertion from lifecycle migrations; allows service-role (caller IS NULL) or admin players
  PERFORM _assert_is_admin();

  -- Advance the game tick (will raise if game not running)
  new_tick := advance_tick(p_game);

  -- Process income for this tick. process_income returns number of player wallets credited.
  income_count := process_income(p_game);

  -- Notify players who received income so realtime clients can react.
  -- Compute the income aggregation the same way process_income does and create a notification per player.
  FOR rec IN
    SELECT c.owner_player_id AS player_id, SUM(cb.count * bt.base_income) AS total_income
    FROM countries c
    JOIN country_buildings cb ON cb.country_id = c.id
    JOIN building_types bt ON bt.id = cb.building_type_id
    WHERE c.game_id = p_game
    GROUP BY c.owner_player_id
  LOOP
    IF rec.player_id IS NULL OR rec.total_income IS NULL OR rec.total_income <= 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
      VALUES (
        gen_random_uuid(),
        rec.player_id,
        'Income credited',
        format('Your wallet has been credited with %s for country income', (rec.total_income::numeric/100)::text),
        jsonb_build_object('game_id', p_game, 'amount', rec.total_income),
        now()
      );
  END LOOP;

  RETURN jsonb_build_object('tick', new_tick, 'income_processed', income_count, 'processed_at', now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: A scheduler (cron, server-side job, or cloud function) should call process_game_tick for each running
-- game when it's time to advance the tick. Keeping this operation in the DB ensures atomicity of tick advancement
-- and income transfers and that all wallet transfers execute under the SECURITY DEFINER privileges.

-- End of migration
