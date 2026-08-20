-- 0014_game_economy_cron_and_rpc_security.sql
-- Keep the economy scheduler active and prevent privileged SECURITY DEFINER
-- functions from being callable through the public Data API by default.

CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('run_due_game_ticks', '* * * * *', $$select run_due_game_ticks();$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'run_due_game_ticks');

SELECT cron.schedule('expire_listings', '*/5 * * * *', $$select expire_listings();$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_listings');

SELECT cron.schedule('expire_stale_bids', '5 0 * * *', $$select expire_stale_bids(7);$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_stale_bids');

SELECT cron.schedule('daily_leaderboard_snapshots', '10 0 * * *', $$select create_leaderboard_snapshots_for_all_games();$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily_leaderboard_snapshots');

SELECT cron.schedule('finish_ended_games', '2 * * * *', $$select finish_ended_games();$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'finish_ended_games');

REVOKE EXECUTE ON FUNCTION public._assert_is_admin() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.advance_tick(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.process_game_tick(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.run_due_game_ticks() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.expire_listings() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.expire_stale_bids(integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_leaderboard_snapshot(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_leaderboard_snapshots_for_all_games() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.finish_ended_games() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.finish_game(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_game_ready(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.start_game(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.pause_game(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.resume_game(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.buy_country_as(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.grant_external_funds(uuid, bigint, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.grant_external_reward(uuid, bigint, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_treasury_wallet(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_wallet_for_player(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.process_income(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_bids() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_countries() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_country_buildings() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_country_listings() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_events_table() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_income_records() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_leaderboard_snapshots() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_players() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_realtime_wallets() FROM PUBLIC, anon, authenticated;

-- Admin lifecycle controls remain callable by signed-in admins; the functions
-- themselves enforce the is_admin check.
GRANT EXECUTE ON FUNCTION public.set_game_ready(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pause_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finish_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_tick(uuid) TO authenticated;
