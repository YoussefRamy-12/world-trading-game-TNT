import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  const body = await req.json();
  const { country_id, building_type_id, quantity = 1 } = body;
  if (!country_id || !building_type_id) return NextResponse.json({ error: 'country_id and building_type_id required' }, { status: 400 });

  const svc = createServiceClient();
  const { data, error } = await svc.rpc('purchase_buildings', { p_country: country_id, p_building_type: building_type_id, p_quantity: quantity });
  if (error) return NextResponse.json({ error }, { status: 500 });
  return NextResponse.json({ id: Array.isArray(data) ? data[0] : data });
}
