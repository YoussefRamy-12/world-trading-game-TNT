-- 0002_game_functions.sql
-- RLS policies and secure server-side functions for game actions

-- Important: functions are SECURITY DEFINER and should be owned by a privileged role (postgres) so they can perform operations that are disallowed by RLS for normal users.

-- Ensure RLS is enabled where appropriate and tighten policies to allow only safe reads from clients.

-- Wallets: clients may SELECT only their own wallets; all writes must go through server functions.
ALTER TABLE IF EXISTS wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wallets_select_policy ON wallets;
CREATE POLICY wallets_select_policy ON wallets
  FOR SELECT USING (player_id = auth.uid()::uuid);

-- No INSERT/UPDATE/DELETE policies created: disallow direct writes from client-side.

-- Wallet transactions: clients can see their own transactions, but cannot insert them directly.
ALTER TABLE IF EXISTS wallet_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wallet_transactions_select_policy ON wallet_transactions;
CREATE POLICY wallet_transactions_select_policy ON wallet_transactions
  FOR SELECT USING (wallet_id IN (SELECT id FROM wallets WHERE player_id = auth.uid()::uuid));

-- Players: clients can see and select only their own player row(s). No direct updates allowed.
ALTER TABLE IF EXISTS players ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS players_select_policy ON players;
CREATE POLICY players_select_policy ON players
  FOR SELECT USING (id = auth.uid()::uuid);

-- Countries: allow public countries to be visible to all, private ones only to their owners.
-- Convention: countries.metadata->>'public' = 'true' indicates a public country.
ALTER TABLE IF EXISTS countries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS countries_select_policy ON countries;
CREATE POLICY countries_select_policy ON countries
  FOR SELECT USING (
    (metadata->> 'public' = 'true') OR (owner_player_id = auth.uid()::uuid)
  );
-- Disallow direct modifications from clients (no write policies)

-- Country listings (marketplace): show only open listings or listings belonging to the calling user.
ALTER TABLE IF EXISTS country_listings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS country_listings_select_policy ON country_listings;
CREATE POLICY country_listings_select_policy ON country_listings
  FOR SELECT USING (status = 'open' OR seller_player_id = auth.uid()::uuid);

-- Bids: allow bidders to see their own bids and listing owners to see bids on their listings
ALTER TABLE IF EXISTS bids ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bids_select_policy ON bids;
CREATE POLICY bids_select_policy ON bids
  FOR SELECT USING (
    bidder_player_id = auth.uid()::uuid
    OR EXISTS (SELECT 1 FROM country_listings cl WHERE cl.id = listing_id AND cl.seller_player_id = auth.uid()::uuid)
  );

-- Notifications: users can see their own notifications. Writes are via server functions only.
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notifications_select_policy ON notifications;
CREATE POLICY notifications_select_policy ON notifications
  FOR SELECT USING (player_id = auth.uid()::uuid);

-- Events and event_participation: participants can see their own participation; events are public for listing
ALTER TABLE IF EXISTS event_participation ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS event_participation_select_policy ON event_participation;
CREATE POLICY event_participation_select_policy ON event_participation
  FOR SELECT USING (player_id = auth.uid()::uuid);

ALTER TABLE IF EXISTS events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS events_select_policy ON events;
CREATE POLICY events_select_policy ON events
  FOR SELECT USING (true);

-- Country buildings and building types: visible; modifications must be via secure functions
ALTER TABLE IF EXISTS country_buildings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS country_buildings_select_policy ON country_buildings;
CREATE POLICY country_buildings_select_policy ON country_buildings
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM countries c WHERE c.id = country_buildings.country_id AND (c.metadata->> 'public' = 'true' OR c.owner_player_id = auth.uid()::uuid))
  );

ALTER TABLE IF EXISTS building_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS building_types_select_policy ON building_types;
CREATE POLICY building_types_select_policy ON building_types
  FOR SELECT USING (true);

-- Helper: ensure a platform/treasury wallet exists for a given currency. Returns wallet id.
CREATE OR REPLACE FUNCTION ensure_treasury_wallet(currency_in text) RETURNS uuid AS $$
DECLARE
  w_id uuid;
BEGIN
  SELECT id INTO w_id FROM wallets WHERE player_id IS NULL AND currency = currency_in LIMIT 1;
  IF w_id IS NULL THEN
    INSERT INTO wallets (id, player_id, currency, balance, created_at, updated_at)
      VALUES (gen_random_uuid(), NULL, currency_in, 0, now(), now()) RETURNING id INTO w_id;
  END IF;
  RETURN w_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Utility: get wallet id for a player and currency, or raise if missing
CREATE OR REPLACE FUNCTION get_wallet_for_player(p_player uuid, p_currency text) RETURNS uuid AS $$
DECLARE
  w uuid;
BEGIN
  SELECT id INTO w FROM wallets WHERE player_id = p_player AND currency = p_currency LIMIT 1;
  IF w IS NULL THEN
    RAISE EXCEPTION 'wallet_not_found for player % and currency %', p_player, p_currency;
  END IF;
  RETURN w;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ACTION FUNCTIONS (SECURITY DEFINER):
-- Sell country: creates a listing for a country owned by the caller.
CREATE OR REPLACE FUNCTION sell_country(p_country uuid, p_price bigint, p_currency text DEFAULT 'USD') RETURNS uuid AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  c_owner uuid;
  listing_id uuid;
BEGIN
  SELECT owner_player_id INTO c_owner FROM countries WHERE id = p_country FOR SHARE;
  IF c_owner IS NULL OR c_owner <> caller THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  INSERT INTO country_listings (country_id, seller_player_id, price, currency, status, created_at, updated_at)
    VALUES (p_country, caller, p_price, p_currency, 'open', now(), now()) RETURNING id INTO listing_id;

  RETURN listing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Place a bid: creates a bid record (does not escrow funds). Server-side validation only.
CREATE OR REPLACE FUNCTION place_bid(p_listing uuid, p_amount bigint, p_currency text DEFAULT 'USD') RETURNS uuid AS $$
DECLARE
  bidder uuid := auth.uid()::uuid;
  listing_country uuid;
  listing_seller uuid;
  listing_status text;
  bid_id uuid;
BEGIN
  SELECT country_id, seller_player_id, status INTO listing_country, listing_seller, listing_status FROM country_listings WHERE id = p_listing FOR SHARE;
  IF listing_country IS NULL THEN
    RAISE EXCEPTION 'listing_not_found';
  END IF;
  IF listing_status <> 'open' THEN
    RAISE EXCEPTION 'listing_not_open';
  END IF;
  IF listing_seller = bidder THEN
    RAISE EXCEPTION 'cannot_bid_on_own_listing';
  END IF;

  -- Basic fund check (no escrow): ensure bidder has at least p_amount in requested currency
  PERFORM 1 FROM wallets w WHERE w.player_id = bidder AND w.currency = p_currency AND w.balance >= p_amount;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'insufficient_funds';
  END IF;

  INSERT INTO bids (listing_id, bidder_player_id, amount, currency, status, created_at)
    VALUES (p_listing, bidder, p_amount, p_currency, 'pending', now()) RETURNING id INTO bid_id;

  RETURN bid_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cancel a bid: only the bidder may cancel a pending bid
CREATE OR REPLACE FUNCTION cancel_bid(p_bid uuid) RETURNS void AS $$
DECLARE
  bidder uuid := auth.uid()::uuid;
  b_listing uuid;
  b_status text;
  b_bidder uuid;
BEGIN
  SELECT listing_id, status, bidder_player_id INTO b_listing, b_status, b_bidder FROM bids WHERE id = p_bid FOR UPDATE;
  IF b_bidder IS NULL THEN
    RAISE EXCEPTION 'bid_not_found';
  END IF;
  IF b_bidder <> bidder THEN
    RAISE EXCEPTION 'not_bidder';
  END IF;
  IF b_status <> 'pending' THEN
    RAISE EXCEPTION 'cannot_cancel_non_pending_bid';
  END IF;

  UPDATE bids SET status = 'cancelled' WHERE id = p_bid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accept a bid: only the seller may accept. This transfers funds atomically and transfers country ownership.
CREATE OR REPLACE FUNCTION accept_bid(p_bid uuid) RETURNS void AS $$
DECLARE
  seller uuid := auth.uid()::uuid;
  bid_rec RECORD;
  listing_rec RECORD;
  buyer_wallet uuid;
  seller_wallet uuid;
  country_id uuid;
BEGIN
  SELECT * INTO bid_rec FROM bids WHERE id = p_bid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bid_not_found';
  END IF;
  IF bid_rec.status <> 'pending' THEN
    RAISE EXCEPTION 'bid_not_pending';
  END IF;

  SELECT * INTO listing_rec FROM country_listings WHERE id = bid_rec.listing_id FOR UPDATE;
  IF listing_rec.status <> 'open' THEN
    RAISE EXCEPTION 'listing_not_open';
  END IF;
  IF listing_rec.seller_player_id <> seller THEN
    RAISE EXCEPTION 'not_listing_seller';
  END IF;

  -- confirm buyer still has funds
  SELECT get_wallet_for_player(bid_rec.bidder_player_id, bid_rec.currency) INTO buyer_wallet;
  SELECT get_wallet_for_player(listing_rec.seller_player_id, bid_rec.currency) INTO seller_wallet;

  -- transfer funds: bidder -> seller
  PERFORM transfer_between_wallets(buyer_wallet, seller_wallet, bid_rec.amount, 'bid_accepted', p_bid, jsonb_build_object('listing_id', listing_rec.id));

  -- update statuses and transfer country ownership
  UPDATE bids SET status = 'accepted' WHERE id = p_bid;
  UPDATE country_listings SET status = 'sold', updated_at = now() WHERE id = listing_rec.id;
  country_id := listing_rec.country_id;
  UPDATE countries SET owner_player_id = bid_rec.bidder_player_id, updated_at = now() WHERE id = country_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Buy country directly at listing price: shorthand that finds listing and performs transfer and ownership transfer
CREATE OR REPLACE FUNCTION buy_country(p_listing uuid) RETURNS void AS $$
DECLARE
  buyer uuid := auth.uid()::uuid;
  listing_rec RECORD;
  buyer_wallet uuid;
  seller_wallet uuid;
BEGIN
  SELECT * INTO listing_rec FROM country_listings WHERE id = p_listing FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found';
  END IF;
  IF listing_rec.status <> 'open' THEN
    RAISE EXCEPTION 'listing_not_open';
  END IF;
  IF listing_rec.seller_player_id = buyer THEN
    RAISE EXCEPTION 'cannot_buy_own_listing';
  END IF;

  SELECT get_wallet_for_player(buyer, listing_rec.currency) INTO buyer_wallet;
  SELECT get_wallet_for_player(listing_rec.seller_player_id, listing_rec.currency) INTO seller_wallet;

  PERFORM transfer_between_wallets(buyer_wallet, seller_wallet, listing_rec.price, 'buy_country', listing_rec.id, jsonb_build_object('country_id', listing_rec.country_id));

  UPDATE country_listings SET status = 'sold', updated_at = now() WHERE id = listing_rec.id;
  UPDATE countries SET owner_player_id = buyer, updated_at = now() WHERE id = listing_rec.country_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Upgrade country building: owner may upgrade their country's building levels by paying cost. Simple cost model: cost = building_types.base_cost * (new_level - old_level)
CREATE OR REPLACE FUNCTION upgrade_country_building(p_country_building uuid, p_new_level integer) RETURNS void AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  cb RECORD;
  btype RECORD;
  cost bigint;
  player_wallet uuid;
BEGIN
  SELECT * INTO cb FROM country_buildings WHERE id = p_country_building FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'country_building_not_found';
  END IF;
  SELECT * INTO btype FROM building_types WHERE id = cb.building_type_id FOR SHARE;
  IF cb IS NULL OR btype IS NULL THEN
    RAISE EXCEPTION 'invalid_building';
  END IF;
  -- verify ownership of country
  IF NOT EXISTS (SELECT 1 FROM countries WHERE id = cb.country_id AND owner_player_id = caller) THEN
    RAISE EXCEPTION 'not_country_owner';
  END IF;
  IF p_new_level <= cb.level THEN
    RAISE EXCEPTION 'new_level_must_be_greater';
  END IF;
  IF p_new_level > btype.max_level THEN
    RAISE EXCEPTION 'exceeds_max_level';
  END IF;

  cost := btype.base_cost * (p_new_level - cb.level);

  SELECT get_wallet_for_player(caller, 'USD') INTO player_wallet; -- assume USD for upgrades; alternatively use metadata

  PERFORM transfer_between_wallets(player_wallet, ensure_treasury_wallet('USD'), cost, 'upgrade_building', cb.id, jsonb_build_object('from_level', cb.level, 'to_level', p_new_level));

  UPDATE country_buildings SET level = p_new_level, updated_at = now() WHERE id = p_country_building;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Process income: compute income per player for a game and credit wallets. This function is intended to be run by a scheduler or admin.
CREATE OR REPLACE FUNCTION process_income(p_game uuid) RETURNS integer AS $$
DECLARE
  row RECORD;
  player_wallet uuid;
  credits integer := 0;
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT c.owner_player_id AS player_id, SUM(cb.count * bt.base_income) AS total_income
    FROM countries c
    JOIN country_buildings cb ON cb.country_id = c.id
    JOIN building_types bt ON bt.id = cb.building_type_id
    WHERE c.game_id = p_game
    GROUP BY c.owner_player_id
  LOOP
    IF rec.player_id IS NULL THEN
      CONTINUE;
    END IF;
    IF rec.total_income IS NULL OR rec.total_income = 0 THEN
      CONTINUE;
    END IF;

    -- ensure player wallet exists for USD
    BEGIN
      SELECT get_wallet_for_player(rec.player_id, 'USD') INTO player_wallet;
    EXCEPTION WHEN others THEN
      -- create wallet if missing
      INSERT INTO wallets (id, player_id, currency, balance, created_at, updated_at)
        VALUES (gen_random_uuid(), rec.player_id, 'USD', 0, now(), now()) RETURNING id INTO player_wallet;
    END;

    -- credit wallet from treasury
    PERFORM transfer_between_wallets(ensure_treasury_wallet('USD'), player_wallet, rec.total_income, 'income', NULL, jsonb_build_object('game_id', p_game));

    INSERT INTO income_records (player_id, amount, source, metadata, created_at)
      VALUES (rec.player_id, rec.total_income, 'building_income', jsonb_build_object('game_id', p_game), now());

    credits := credits + 1;
  END LOOP;

  RETURN credits;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Administrative: safe accept/deny functions could be added; ensure function owners are a privileged role.

-- Notes:
-- 1) These SECURITY DEFINER functions assume the function owner has privileges to bypass RLS. In a Supabase environment, function ownership should be set to the postgres service role or another role with BYPASSRLS if you intend these functions to be the only way to change critical data from client-side calls.
-- 2) Clients should call these functions via RPC (Supabase functions) or via server-side endpoints that use a service role key. Do not call them directly from untrusted clients unless you rely on auth.uid() checks in the functions.
-- 3) Review and expand policies and function checks for edge cases (currencies other than USD, concurrent bids, escrow, etc.).

-- End of migration
