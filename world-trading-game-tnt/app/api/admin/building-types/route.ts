import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';

export const dynamic = 'force-dynamic';

export async function GET() {
  const svc = createServiceClient();
  const { data, error } = await svc.from('building_types').select('*').order('id', { ascending: true });
  if (error) return NextResponse.json({ error }, { status: 500 });
  return NextResponse.json(data);
}

export async function POST(req: Request) {
  const body = await req.json();
  const { id = null, slug, name, base_cost, base_income = 0, maintenance_cost = 0, max_level = 1, metadata = {} } = body;
  if (!slug || !name || base_cost == null) return NextResponse.json({ error: 'slug, name, base_cost required' }, { status: 400 });
  const svc = createServiceClient();
  const { data, error } = await svc.rpc('admin_upsert_building_type', { p_id: id, p_slug: slug, p_name: name, p_base_cost: base_cost, p_base_income: base_income, p_maintenance: maintenance_cost, p_max_level: max_level, p_metadata: metadata });
  if (error) return NextResponse.json({ error }, { status: 500 });
  return NextResponse.json({ id: Array.isArray(data) ? data[0] : data });
}
