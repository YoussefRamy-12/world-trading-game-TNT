-- 0009_marketplace.sql
-- Marketplace enhancements: listing expiry, bid rejection, listing cancellation and expiry processing

-- Add optional expiry timestamp to listings
ALTER TABLE IF EXISTS country_listings ADD COLUMN IF NOT EXISTS expires_at timestamptz;

-- Overwrite sell_country to accept optional expiry (keeps backward compatible defaults)
CREATE OR REPLACE FUNCTION sell_country(p_country uuid, p_price bigint, p_currency text DEFAULT 'USD', p_expires_at timestamptz DEFAULT NULL) RETURNS uuid AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  c_owner uuid;
  listing_id uuid;
BEGIN
  SELECT owner_player_id INTO c_owner FROM countries WHERE id = p_country FOR SHARE;
  IF c_owner IS NULL OR c_owner <> caller THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  INSERT INTO country_listings (country_id, seller_player_id, price, currency, status, expires_at, created_at, updated_at)
    VALUES (p_country, caller, p_price, p_currency, 'open', p_expires_at, now(), now()) RETURNING id INTO listing_id;

  RETURN listing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Seller may cancel their open listing; pending bids are rejected and bidders notified
CREATE OR REPLACE FUNCTION cancel_listing(p_listing uuid) RETURNS void AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  listing_rec RECORD;
  bid_rec RECORD;
BEGIN
  SELECT * INTO listing_rec FROM country_listings WHERE id = p_listing FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found';
  END IF;
  IF listing_rec.seller_player_id <> caller THEN
    RAISE EXCEPTION 'not_listing_seller';
  END IF;
  IF listing_rec.status <> 'open' THEN
    RAISE EXCEPTION 'listing_not_open';
  END IF;

  -- mark listing cancelled
  UPDATE country_listings SET status = 'cancelled', updated_at = now() WHERE id = p_listing;

  -- reject any pending bids and notify bidders
  FOR bid_rec IN SELECT * FROM bids WHERE listing_id = p_listing AND status = 'pending' FOR UPDATE
  LOOP
    UPDATE bids SET status = 'rejected' WHERE id = bid_rec.id;

    INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
      VALUES (
        gen_random_uuid(),
        bid_rec.bidder_player_id,
        'Bid rejected',
        format('Your bid of %s on a listing was rejected because the seller cancelled the listing', (bid_rec.amount::numeric/100)::text),
        jsonb_build_object('listing_id', p_listing, 'reason', 'seller_cancelled'),
        now()
      );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Seller may explicitly reject a single pending bid
CREATE OR REPLACE FUNCTION reject_bid(p_bid uuid) RETURNS void AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  bid_rec RECORD;
  listing_rec RECORD;
BEGIN
  SELECT * INTO bid_rec FROM bids WHERE id = p_bid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bid_not_found';
  END IF;
  IF bid_rec.status <> 'pending' THEN
    RAISE EXCEPTION 'bid_not_pending';
  END IF;

  SELECT * INTO listing_rec FROM country_listings WHERE id = bid_rec.listing_id FOR SHARE;
  IF listing_rec.seller_player_id <> caller THEN
    RAISE EXCEPTION 'not_listing_seller';
  END IF;

  UPDATE bids SET status = 'rejected' WHERE id = p_bid;

  INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
    VALUES (
      gen_random_uuid(),
      bid_rec.bidder_player_id,
      'Bid rejected',
      format('Your bid of %s on listing %s was rejected by the seller', (bid_rec.amount::numeric/100)::text, listing_rec.id::text),
      jsonb_build_object('listing_id', listing_rec.id, 'reason', 'seller_rejected'),
      now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Expire listings whose expires_at has passed: mark listing as 'expired', reject pending bids, notify bidders and seller
CREATE OR REPLACE FUNCTION expire_listings() RETURNS integer AS $$
DECLARE
  listing_rec RECORD;
  bid_rec RECORD;
  count_expired integer := 0;
BEGIN
  FOR listing_rec IN SELECT * FROM country_listings WHERE status = 'open' AND expires_at IS NOT NULL AND expires_at <= now() FOR UPDATE
  LOOP
    -- mark listing expired
    UPDATE country_listings SET status = 'expired', updated_at = now() WHERE id = listing_rec.id;

    -- notify seller
    INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
      VALUES (
        gen_random_uuid(),
        listing_rec.seller_player_id,
        'Listing expired',
        format('Your listing for country %s has expired without a sale', listing_rec.country_id::text),
        jsonb_build_object('listing_id', listing_rec.id),
        now()
      );

    -- reject pending bids and notify bidders
    FOR bid_rec IN SELECT * FROM bids WHERE listing_id = listing_rec.id AND status = 'pending' FOR UPDATE
    LOOP
      UPDATE bids SET status = 'rejected' WHERE id = bid_rec.id;

      INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
        VALUES (
          gen_random_uuid(),
          bid_rec.bidder_player_id,
          'Bid rejected',
          format('Your bid of %s on listing %s was rejected because the listing expired', (bid_rec.amount::numeric/100)::text, listing_rec.id::text),
          jsonb_build_object('listing_id', listing_rec.id, 'reason', 'listing_expired'),
          now()
        );
    END LOOP;

    count_expired := count_expired + 1;
  END LOOP;

  RETURN count_expired;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- End of migration
