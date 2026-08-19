import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';

export const dynamic = 'force-dynamic';

// GET /api/countries - list public countries with basic info and computed value
export async function GET() {
  const svc = createServiceClient();

  const { data: countries, error: e } = await svc.from('countries').select('id, name, code, population, resources, owner_player_id').filter("(metadata->>'public')", 'eq', 'true');
  if (e) return NextResponse.json({ error: e }, { status: 500 });

  const results = [];
  for (const c of countries) {
    const { data: v, error: ve } = await svc.rpc('country_value', { p_country: c.id });
    let value = null;
    if (!ve && v !== null) {
      // rpc returns a scalar bigint in an array for pg-js; handle both
      if (Array.isArray(v)) value = v[0]; else value = v;
    }
    results.push({ id: c.id, name: c.name, code: c.code, population: c.population, value: value });
  }

  return NextResponse.json(results);
}
