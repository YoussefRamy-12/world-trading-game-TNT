-- 0007_upgrades.sql
-- Purchase and upgrade helpers: purchase_buildings and admin controls suggested

-- purchase_buildings: player buys X units of a building type for a country (charges base_cost * quantity)
CREATE OR REPLACE FUNCTION purchase_buildings(p_country uuid, p_building_type integer, p_quantity integer DEFAULT 1) RETURNS uuid AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  c_owner uuid;
  bt RECORD;
  cb_id uuid;
  player_wallet uuid;
  treasury uuid;
  total_cost bigint;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'invalid_quantity';
  END IF;

  SELECT owner_player_id INTO c_owner FROM countries WHERE id = p_country FOR SHARE;
  IF c_owner IS NULL OR c_owner <> caller THEN
    RAISE EXCEPTION 'not_country_owner';
  END IF;

  SELECT * INTO bt FROM building_types WHERE id = p_building_type FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'building_type_not_found';
  END IF;

  -- calculate cost: base_cost * quantity (could be extended with scaling)
  total_cost := bt.base_cost * p_quantity;

  -- ensure player wallet exists and has funds
  SELECT get_wallet_for_player(caller, 'USD') INTO player_wallet;

  -- ensure treasury
  treasury := ensure_treasury_wallet('USD');

  -- transfer funds
  PERFORM transfer_between_wallets(player_wallet, treasury, total_cost, 'purchase_buildings', NULL, jsonb_build_object('country_id', p_country, 'building_type', bt.id, 'quantity', p_quantity));

  -- insert or update country_buildings
  SELECT id INTO cb_id FROM country_buildings WHERE country_id = p_country AND building_type_id = p_building_type FOR UPDATE;
  IF cb_id IS NULL THEN
    INSERT INTO country_buildings (id, country_id, building_type_id, level, count, installed_at, updated_at)
      VALUES (gen_random_uuid(), p_country, p_building_type, 1, p_quantity, now(), now()) RETURNING id INTO cb_id;
  ELSE
    UPDATE country_buildings SET count = count + p_quantity, updated_at = now() WHERE id = cb_id;
  END IF;

  RETURN cb_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin helper: set building type properties (safe to be called via admin APIs)
CREATE OR REPLACE FUNCTION admin_upsert_building_type(p_id integer DEFAULT NULL, p_slug text, p_name text, p_base_cost bigint, p_base_income bigint DEFAULT 0, p_maintenance bigint DEFAULT 0, p_max_level integer DEFAULT 1, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS integer AS $$
DECLARE
  out_id integer;
BEGIN
  PERFORM _assert_is_admin();
  IF p_id IS NOT NULL THEN
    UPDATE building_types SET slug = p_slug, name = p_name, base_cost = p_base_cost, base_income = p_base_income, maintenance_cost = p_maintenance, max_level = p_max_level, metadata = COALESCE(p_metadata, '{}'::jsonb), updated_at = now() WHERE id = p_id RETURNING id INTO out_id;
    IF FOUND THEN RETURN out_id; END IF;
  END IF;
  INSERT INTO building_types (slug, name, base_cost, base_income, maintenance_cost, max_level, metadata, created_at, updated_at)
    VALUES (p_slug, p_name, p_base_cost, p_base_income, p_maintenance, p_max_level, COALESCE(p_metadata, '{}'::jsonb), now(), now()) RETURNING id INTO out_id;
  RETURN out_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- End of migration
