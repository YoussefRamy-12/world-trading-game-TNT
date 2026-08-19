-- 0013_scheduled_jobs.sql
-- Scheduled game jobs helper functions and optional pg_cron registration
-- Provides functions to run due game ticks, expire stale bids, create daily leaderboards across games,
-- and finish games based on a configured end time. If pg_cron is installed, this migration will
-- register cron jobs to run these functions periodically.

-- 1) Run due game ticks: finds running games whose next tick is due and calls process_game_tick(game_id)
CREATE OR REPLACE FUNCTION run_due_game_ticks() RETURNS integer AS $$
DECLARE
  g RECORD;
  processed integer := 0;
  next_due timestamptz;
BEGIN
  FOR g IN SELECT id, last_tick_at, tick_interval_seconds FROM games WHERE state = 'running' FOR UPDATE SKIP LOCKED
  LOOP
    IF g.last_tick_at IS NULL THEN
      next_due := COALESCE(g.last_tick_at, g.started_at);
    ELSE
      next_due := g.last_tick_at + make_interval(secs => g.tick_interval_seconds);
    END IF;

    IF g.last_tick_at IS NULL OR now() >= next_due THEN
      BEGIN
        PERFORM process_game_tick(g.id);
        processed := processed + 1;
      EXCEPTION WHEN others THEN
        -- Don't fail the whole job if one game's tick fails; record notice and continue
        RAISE NOTICE 'process_game_tick failed for %: %', g.id, SQLERRM;
      END;
    END IF;
  END LOOP;

  RETURN processed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2) Expire stale pending bids older than p_days (default 7) and notify bidders
CREATE OR REPLACE FUNCTION expire_stale_bids(p_days integer DEFAULT 7) RETURNS integer AS $$
DECLARE
  b RECORD;
  cutoff timestamptz := now() - (p_days || ' days')::interval;
  count_rejected integer := 0;
BEGIN
  FOR b IN SELECT * FROM bids WHERE status = 'pending' AND created_at <= cutoff FOR UPDATE
  LOOP
    UPDATE bids SET status = 'rejected' WHERE id = b.id;

    INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
      VALUES (
        gen_random_uuid(),
        b.bidder_player_id,
        'Bid expired',
        format('Your bid of %s on listing %s expired and was rejected', (b.amount::numeric/100)::text, b.listing_id::text),
        jsonb_build_object('bid_id', b.id, 'listing_id', b.listing_id, 'reason', 'stale_bid'),
        now()
      );

    count_rejected := count_rejected + 1;
  END LOOP;

  RETURN count_rejected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Create leaderboard snapshots for all running games (can be scheduled daily or after ticks)
CREATE OR REPLACE FUNCTION create_leaderboard_snapshots_for_all_games() RETURNS integer AS $$
DECLARE
  g RECORD;
  count_snapshots integer := 0;
BEGIN
  FOR g IN SELECT id FROM games WHERE state = 'running' FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      PERFORM create_leaderboard_snapshot(g.id);
      count_snapshots := count_snapshots + 1;
    EXCEPTION WHEN others THEN
      RAISE NOTICE 'create_leaderboard_snapshot failed for %: %', g.id, SQLERRM;
    END;
  END LOOP;
  RETURN count_snapshots;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4) Finish games whose config contains an 'ends_at' timestamp that has passed
CREATE OR REPLACE FUNCTION finish_ended_games() RETURNS integer AS $$
DECLARE
  g RECORD;
  ends_at timestamptz;
  finished_count integer := 0;
BEGIN
  FOR g IN SELECT id, config FROM games WHERE state != 'finished' FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      IF g.config ? 'ends_at' THEN
        ends_at := (g.config->> 'ends_at')::timestamptz;
        IF ends_at IS NOT NULL AND now() >= ends_at THEN
          PERFORM finish_game(g.id);
          finished_count := finished_count + 1;
        END IF;
      END IF;
    EXCEPTION WHEN others THEN
      RAISE NOTICE 'finish_ended_games error for %: %', g.id, SQLERRM;
    END;
  END LOOP;

  RETURN finished_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5) Attempt to register pg_cron jobs if extension exists. These are safe no-ops if pg_cron is not installed.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- run due ticks every minute
    PERFORM cron.schedule('run_due_game_ticks', '*/1 * * * *', 'SELECT run_due_game_ticks();');

    -- expire listings every 5 minutes (uses expire_listings() created earlier)
    PERFORM cron.schedule('expire_listings', '*/5 * * * *', 'SELECT expire_listings();');

    -- expire stale bids daily at 00:05
    PERFORM cron.schedule('expire_stale_bids', '5 0 * * *', 'SELECT expire_stale_bids(7);');

    -- create leaderboard snapshots daily at 00:10
    PERFORM cron.schedule('daily_leaderboard_snapshots', '10 0 * * *', 'SELECT create_leaderboard_snapshots_for_all_games();');

    -- finish ended games hourly at minute 2
    PERFORM cron.schedule('finish_ended_games', '2 * * * *', 'SELECT finish_ended_games();');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- End of migration
