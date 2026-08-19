/* eslint-disable @typescript-eslint/no-require-imports */
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function run() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('DATABASE_URL env var is required.');
    process.exit(1);
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to', connectionString.split('@')[1] || 'database');
    await client.connect();

    const migrationsDir = path.resolve(__dirname, '..', 'supabase', 'migrations');
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
    if (files.length === 0) {
      console.log('No migration files found in', migrationsDir);
      await client.end();
      return;
    }

    for (const f of files) {
      const filePath = path.join(migrationsDir, f);
      console.log('\n---- Applying', filePath, '----');
      const sql = fs.readFileSync(filePath, 'utf8');
      try {
        await client.query(sql);
        console.log('Applied', f);
      } catch (err) {
        console.error('Error applying', f);
        throw err;
      }
    }

    console.log('\nAll migrations applied successfully.');

    // Optional: basic verification
    const res = await client.query("SELECT relname, relrowsecurity FROM pg_class WHERE relname IN ('wallets','wallet_transactions','countries','country_listings','bids','players','notifications','country_buildings','event_participation')");
    console.table(res.rows);

    // List functions created
    const fnRes = await client.query("SELECT proname, pg_get_userbyid(proowner) AS owner, prosecdef FROM pg_proc JOIN pg_namespace n ON pg_proc.pronamespace = n.oid WHERE n.nspname='public' AND proname IN ('transfer_between_wallets','ensure_treasury_wallet','get_wallet_for_player','sell_country','place_bid','cancel_bid','accept_bid','buy_country','upgrade_country_building','process_income','update_updated_at_column');");
    console.log('\nFunctions:');
    console.table(fnRes.rows);

    await client.end();
  } catch (err) {
    console.error('Migration run failed:', err instanceof Error ? err.message : String(err));
    try { await client.end(); } catch {
      // ignore cleanup errors
    }
    process.exit(1);
  }
}

run();
