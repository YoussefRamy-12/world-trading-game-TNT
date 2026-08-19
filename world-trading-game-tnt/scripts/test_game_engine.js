/*
  Simple integration tests for core DB functions of the game engine.
  Requires DATABASE_URL env var pointing to a test database with migrations applied.

  Tests included:
  - transfer_between_wallets prevents negative balances and updates balances atomically
  - concurrent transfers from same wallet: only one should succeed when funds are limited
  - double-click transfer: calling same transfer twice results in single successful transfer
  - process_income credits wallets and inserts income_records

  Run locally with:
    DATABASE_URL=postgres://... node scripts/test_game_engine.js
*/

/* eslint-disable @typescript-eslint/no-require-imports */
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function query(sql, params) {
  const client = await pool.connect();
  try {
    const res = await client.query(sql, params);
    return res;
  } finally {
    client.release();
  }
}

async function setupTestPlayers() {
  // create two players and wallets
  const res = await query(`
    INSERT INTO players (display_name) VALUES ('test_player_a') RETURNING id
  `);
  const playerA = res.rows[0].id;

  const res2 = await query(`INSERT INTO players (display_name) VALUES ('test_player_b') RETURNING id`);
  const playerB = res2.rows[0].id;

  return { playerA, playerB };
}

async function createWallet(playerId, currency = 'USD', balance = 0) {
  const res = await query(
    `INSERT INTO wallets (player_id, currency, balance) VALUES ($1,$2,$3) RETURNING id, balance`,
    [playerId, currency, balance]
  );
  return res.rows[0];
}

async function getWalletBalance(walletId) {
  const res = await query(`SELECT balance FROM wallets WHERE id = $1`, [walletId]);
  return res.rows[0].balance;
}

async function transfer(from, to, amount) {
  try {
    await query(`SELECT transfer_between_wallets($1,$2,$3,'test_transfer',NULL, '{}'::jsonb)`, [from, to, amount]);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  }
}

async function test_transfer_prevent_negative() {
  console.log('Running test_transfer_prevent_negative');
  const { playerA, playerB } = await setupTestPlayers();
  const wA = await createWallet(playerA, 'USD', 1000);
  const wB = await createWallet(playerB, 'USD', 0);

  const r1 = await transfer(wA.id, wB.id, 2000);
  if (r1.ok) throw new Error('Expected transfer to fail due to insufficient funds');
  console.log('  insufficient funds correctly prevented');

  const r2 = await transfer(wA.id, wB.id, 1000);
  if (!r2.ok) throw new Error('Expected transfer to succeed for exact balance');
  const bA = await getWalletBalance(wA.id);
  const bB = await getWalletBalance(wB.id);
  if (bA !== 0) throw new Error('Expected from wallet to be 0 after exact transfer');
  if (bB !== 1000) throw new Error('Expected to wallet to be credited 1000');

  console.log('  exact-balance transfer succeeded and balances are correct');
}

async function test_concurrent_transfers() {
  console.log('Running test_concurrent_transfers');
  const { playerA, playerB } = await setupTestPlayers();
  const { playerC } = await (async () => {
    const res = await query(`INSERT INTO players (display_name) VALUES ('test_player_c') RETURNING id`);
    return { playerC: res.rows[0].id };
  })();

  const wFrom = await createWallet(playerA, 'USD', 1000);
  const wTo1 = await createWallet(playerB, 'USD', 0);
  const wTo2 = await createWallet(playerC, 'USD', 0);

  // Two concurrent transfers of 700 each from the same wallet of balance 1000.
  // Only one should succeed.
  const p1 = transfer(wFrom.id, wTo1.id, 700);
  const p2 = transfer(wFrom.id, wTo2.id, 700);

  const results = await Promise.all([p1, p2]);
  const successes = results.filter(r => r.ok).length;
  if (successes !== 1) throw new Error('Expected exactly one transfer to succeed under concurrent transfers');

  const finalFrom = await getWalletBalance(wFrom.id);
  const finalTo1 = await getWalletBalance(wTo1.id);
  const finalTo2 = await getWalletBalance(wTo2.id);

  if ((finalTo1 + finalTo2) !== (1000 - finalFrom)) throw new Error('Balances inconsistent after concurrent transfers');

  console.log('  concurrent transfer test passed (one success, one failure)');
}

async function test_double_click_single_transaction() {
  console.log('Running test_double_click_single_transaction');
  const { playerA, playerB } = await setupTestPlayers();
  const wFrom = await createWallet(playerA, 'USD', 500);
  const wTo = await createWallet(playerB, 'USD', 0);

  // simulate double click: two sequential transfers of 500
  const r1 = await transfer(wFrom.id, wTo.id, 500);
  const r2 = await transfer(wFrom.id, wTo.id, 500);

  if (!r1.ok) throw new Error('First transfer should succeed');
  if (r2.ok) throw new Error('Second transfer should fail due to insufficient funds');

  const finalFrom = await getWalletBalance(wFrom.id);
  const finalTo = await getWalletBalance(wTo.id);
  if (finalFrom !== 0 || finalTo !== 500) throw new Error('Balances incorrect after double-click simulation');

  console.log('  double-click transfer test passed');
}

async function test_process_income_once() {
  console.log('Running test_process_income_once');
  // create a game, player, country, building type and country_building, and run process_income
  const gRes = await query(`INSERT INTO games (slug,name) VALUES ('test-game','Test Game') RETURNING id`);
  const gameId = gRes.rows[0].id;
  const pRes = await query(`INSERT INTO players (display_name) VALUES ('income_player') RETURNING id`);
  const playerId = pRes.rows[0].id;

  // ensure treasury wallet exists and player wallet
  await query(`INSERT INTO wallets (player_id, currency, balance) VALUES ($1,'USD',0) ON CONFLICT (player_id,currency) DO NOTHING`, [playerId]);

  // create a building type and country + country_building
  const bt = await query(`INSERT INTO building_types (slug,name,base_cost,base_income) VALUES ('factory','Factory',1000,200) RETURNING id`);
  const btId = bt.rows[0].id;

  const c = await query(`INSERT INTO countries (game_id,name,owner_player_id,population) VALUES ($1,'IncomeLand',$2,1000) RETURNING id`, [gameId, playerId]);
  const countryId = c.rows[0].id;

  await query(`INSERT INTO country_buildings (country_id, building_type_id, level, count) VALUES ($1,$2,1,2)`, [countryId, btId]);

  // record player wallet before
  const w = await query(`SELECT id,balance FROM wallets WHERE player_id = $1 AND currency='USD' LIMIT 1`, [playerId]);
  let walletId;
  let before = 0;
  if (w.rows.length === 0) {
    const created = await query(`INSERT INTO wallets (player_id,currency,balance) VALUES ($1,'USD',0) RETURNING id,balance`, [playerId]);
    walletId = created.rows[0].id;
    before = 0;
  } else {
    walletId = w.rows[0].id;
    before = Number(w.rows[0].balance);
  }

  // run process_income for this game
  const res = await query(`SELECT process_income($1) as cnt`, [gameId]);
  const cnt = res.rows[0].cnt;
  if (cnt < 1) throw new Error('Expected at least one player credited by process_income');

  // verify income_records created and wallet credited
  const inc = await query(`SELECT SUM(amount) as total FROM income_records WHERE player_id = $1`, [playerId]);
  const totalIncome = Number(inc.rows[0].total || 0);
  if (totalIncome <= 0) throw new Error('Expected income_records to be > 0');

  const afterBalRes = await query(`SELECT balance FROM wallets WHERE id = $1`, [walletId]);
  const after = Number(afterBalRes.rows[0].balance);
  if (after <= before) throw new Error('Expected player wallet balance to increase after income');

  console.log('  process_income test passed');
}

async function runAll() {
  try {
    await test_transfer_prevent_negative();
    await test_concurrent_transfers();
    await test_double_click_single_transaction();
    await test_process_income_once();
    console.log('\nALL TESTS PASSED');
    process.exit(0);
  } catch (e) {
    console.error('\nTEST FAILED:', e instanceof Error ? e.message : String(e));
    console.error(e);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runAll();
