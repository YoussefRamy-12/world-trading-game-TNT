import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';

export const dynamic = 'force-dynamic';

export async function GET(
  req: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const svc = createServiceClient();

  // Call get_country_details RPC; it respects RLS since it's SECURITY INVOKER
  const { data, error } = await svc.rpc('get_country_details', { p_country: id });
  if (error) return NextResponse.json({ error }, { status: 500 });

  // rpc returns a jsonb scalar usually as an array; normalize
  let payload = null;
  if (Array.isArray(data)) payload = data[0]; else payload = data;

  if (!payload) return NextResponse.json({ error: 'not_found' }, { status: 404 });
  return NextResponse.json(payload);
}
