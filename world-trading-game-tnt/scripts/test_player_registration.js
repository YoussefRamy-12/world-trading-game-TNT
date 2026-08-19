/*
  Usage:
    1) Install deps: npm install @supabase/supabase-js
    2) Set env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE (for admin grant)
    3) Run: node scripts/test_player_registration.js
*/

/* eslint-disable @typescript-eslint/no-require-imports, @typescript-eslint/no-unused-vars */
const { createClient } = require('@supabase/supabase-js');

const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const anon = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const service = process.env.SUPABASE_SERVICE_ROLE;

if (!url || !anon) {
  console.error('Set SUPABASE_URL and SUPABASE_ANON_KEY in env');
  process.exit(1);
}

async function main() {
  const supabase = createClient(url, anon);

  // 1) sign up a new test user (or sign in existing)
  const email = `test+${Date.now()}@example.com`;
  const password = 'Test1234!';
  console.log('Signing up', email);
  const { data: signUpData, error: signUpErr } = await supabase.auth.signUp({ email, password });
  if (signUpErr) {
    console.error('signUpErr', signUpErr);
    process.exit(1);
  }
  const user = signUpData.user;
  console.log('User created', user.id);

  // NOTE: In Supabase you may need to confirm email; for testing use a project with auto-confirm enabled, or use an existing user
  // 2) Call register_player RPC (will use auth.uid())
  console.log('Calling register_player RPC (requires signed-in session)');
  // Supabase client must have session: this script won't wait for email confirmation; in a dev project you can create player via SQL instead.
  const { data: regData, error: regErr } = await supabase.rpc('register_player', { p_display_name: 'testuser' });
  if (regErr) console.error('register_player error', regErr);
  else console.log('register_player result', regData);

  // For join_game, call RPC once player is registered and the game exists
  // Example: await supabase.rpc('join_game', { p_game: '<GAME_UUID>' });

  // Admin grant example using service role (server call):
  if (service) {
    const svc = createClient(url, service);
    // Replace with real player id from registration or SQL
    // await svc.rpc('grant_external_funds', { p_player: '<PLAYER_UUID>', p_amount: 100000, p_currency: 'USD' });
    console.log('Service role available — you can call grant_external_funds via svc.rpc');
  } else {
    console.log('SUPABASE_SERVICE_ROLE not set; skipping admin grant test');
  }
}

main().catch(err => console.error(err));
