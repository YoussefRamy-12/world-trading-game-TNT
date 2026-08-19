import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';

type CountryInput = {
  id?: string | number;
  game_id?: string | null;
  name?: string;
  code?: string | null;
  owner_player_id?: string | null;
  population?: number | string | null;
  resources?: Record<string, unknown> | null;
  metadata?: Record<string, unknown> | null;
  created_at?: string;
  updated_at?: string;
};

export async function POST(req: Request) {
  const body = (await req.json()) as { countries?: unknown };
  const { countries } = body;
  if (!Array.isArray(countries)) return NextResponse.json({ error: 'countries array required' }, { status: 400 });

  const svc = createServiceClient();

  const toInsert = countries.map((c) => {
    const country = c as Partial<CountryInput>;
    return {
      id: country.id ?? undefined,
      game_id: country.game_id ?? null,
      name: typeof country.name === 'string' ? country.name : '',
      code: country.code ?? null,
      owner_player_id: country.owner_player_id ?? null,
      population: Number(country.population ?? 0) || 0,
      resources: country.resources ?? {},
      metadata: country.metadata ?? {},
      created_at: country.created_at ?? undefined,
      updated_at: country.updated_at ?? undefined,
    };
  });

  const { data, error } = await svc.from('countries').insert(toInsert).select('id');
  if (error) return NextResponse.json({ error }, { status: 500 });

  return NextResponse.json({ inserted: Array.isArray(data) ? data.length : 0, ids: data });
}
