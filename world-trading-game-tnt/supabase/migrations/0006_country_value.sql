-- 0006_country_value.sql
-- Functions to calculate country value and return country details

-- country_total_building_value: sum of building base_cost * count * level_multiplier
CREATE OR REPLACE FUNCTION country_total_building_value(p_country uuid) RETURNS bigint AS $$
DECLARE
  rec RECORD;
  total bigint := 0;
BEGIN
  FOR rec IN
    SELECT cb.count, cb.level, bt.base_cost
    FROM country_buildings cb
    JOIN building_types bt ON bt.id = cb.building_type_id
    WHERE cb.country_id = p_country
  LOOP
    -- level multiplier: 1.0 + 0.5 * (level - 1)
    total := total + (bt.base_cost * cb.count * (100 + (cb.level - 1) * 50) / 100);
  END LOOP;
  RETURN total;
END;
$$ LANGUAGE plpgsql;

-- country_value: sum of building value + population valuation (100 cents per person) + resource valuation placeholder
CREATE OR REPLACE FUNCTION country_value(p_country uuid) RETURNS bigint AS $$
DECLARE
  bval bigint := 0;
  pop bigint := 0;
  res jsonb;
  res_val bigint := 0;
BEGIN
  SELECT population, resources INTO pop, res FROM countries WHERE id = p_country LIMIT 1;
  IF pop IS NULL THEN pop := 0; END IF;
  bval := country_total_building_value(p_country);

  -- simple population valuation: 100 cents per person
  res_val := COALESCE(pop,0) * 100;

  -- TODO: expand resource valuation based on resources jsonb
  RETURN bval + res_val;
END;
$$ LANGUAGE plpgsql;

-- get_country_details: returns jsonb with country, owner minimal info, buildings array and computed value
CREATE OR REPLACE FUNCTION get_country_details(p_country uuid) RETURNS jsonb AS $$
DECLARE
  c RECORD;
  owner RECORD;
  buildings jsonb;
  brec RECORD;
  barray jsonb := '[]'::jsonb;
  val bigint;
BEGIN
  SELECT * INTO c FROM countries WHERE id = p_country LIMIT 1;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT id, display_name, avatar_url INTO owner FROM players WHERE id = c.owner_player_id LIMIT 1;

  FOR brec IN
    SELECT cb.id, cb.building_type_id, bt.slug AS type_slug, bt.name AS type_name, cb.level, cb.count, bt.base_cost
    FROM country_buildings cb
    JOIN building_types bt ON bt.id = cb.building_type_id
    WHERE cb.country_id = p_country
  LOOP
    barray := barray || jsonb_build_object(
      'id', brec.id,
      'type_id', brec.building_type_id,
      'type_slug', brec.type_slug,
      'type_name', brec.type_name,
      'level', brec.level,
      'count', brec.count,
      'base_cost', brec.base_cost
    );
  END LOOP;

  val := country_value(p_country);

  RETURN jsonb_build_object(
    'country', to_jsonb(c) - 'resources', -- omit raw resources to avoid leaking
    'owner', to_jsonb(owner),
    'buildings', barray,
    'value', val
  );
END;
$$ LANGUAGE plpgsql;

-- Note: These functions are SECURITY INVOKER by default to respect RLS and auth.uid().
-- If you need them to bypass RLS for admin reads, convert to SECURITY DEFINER and set owner to postgres.

-- End of migration
