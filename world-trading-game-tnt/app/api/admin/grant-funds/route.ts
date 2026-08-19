import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  const body = await req.json();
  const { player_id, amount, currency = 'USD', reference_id = null } = body;
  if (!player_id || !amount) return NextResponse.json({ error: 'player_id and amount required' }, { status: 400 });

  const svc = createServiceClient();
  const { error } = await svc.rpc('grant_external_funds', { p_player: player_id, p_amount: amount, p_currency: currency, p_reference: reference_id });
  if (error) return NextResponse.json({ error }, { status: 500 });
  return NextResponse.json({ ok: true });
}
