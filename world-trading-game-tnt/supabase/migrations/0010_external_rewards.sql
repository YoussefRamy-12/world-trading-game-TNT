-- 0010_external_rewards.sql
-- Admin-only reward minting: grant_external_reward
-- Grants in-game currency to a player's wallet as an admin reward. This operation is atomic and
-- records a wallet transaction, an external_currency_transactions audit row, and a notification.

CREATE OR REPLACE FUNCTION grant_external_reward(
  p_player uuid,
  p_amount bigint,
  p_currency text DEFAULT 'USD',
  p_reason text DEFAULT 'admin_reward',
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid AS $$
DECLARE
  caller uuid := auth.uid()::uuid;
  tx_id uuid := gen_random_uuid();
  w_id uuid;
  bal_before bigint := 0;
BEGIN
  -- Only allow admins or service-role callers
  PERFORM _assert_is_admin();

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'amount_must_be_positive';
  END IF;

  -- Try to select and lock existing wallet for update
  SELECT id, balance INTO w_id, bal_before FROM wallets WHERE player_id = p_player AND currency = p_currency LIMIT 1 FOR UPDATE;

  -- If wallet missing, create it (balance starts at 0)
  IF w_id IS NULL THEN
    INSERT INTO wallets (id, player_id, currency, balance, created_at, updated_at)
      VALUES (gen_random_uuid(), p_player, p_currency, 0, now(), now()) RETURNING id INTO w_id;
    bal_before := 0;
  END IF;

  -- Credit the player's wallet (minting from system)
  UPDATE wallets SET balance = balance + p_amount, updated_at = now() WHERE id = w_id;

  -- Insert wallet transaction audit record referencing this reward
  INSERT INTO wallet_transactions (wallet_id, amount, balance_before, balance_after, event_type, reference_id, metadata, created_at)
    VALUES (w_id, p_amount, bal_before, bal_before + p_amount, 'admin_reward', tx_id, p_metadata || jsonb_build_object('reason', p_reason), now());

  -- Record in external_currency_transactions as a completed internal reward for auditing
  INSERT INTO external_currency_transactions (id, player_id, provider, provider_tx_id, amount, currency, status, metadata, created_at)
    VALUES (tx_id, p_player, 'internal_reward', NULL, p_amount, p_currency, 'completed', p_metadata || jsonb_build_object('reason', p_reason), now());

  -- Notify the player for realtime clients
  INSERT INTO notifications (id, player_id, title, body, metadata, created_at)
    VALUES (
      gen_random_uuid(),
      p_player,
      'Reward received',
      format('You have received %s %s as a reward', (p_amount::numeric/100)::text, p_currency),
      jsonb_build_object('amount', p_amount, 'currency', p_currency, 'reason', p_reason, 'tx_id', tx_id) || p_metadata,
      now()
    );

  RETURN tx_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- End of migration
