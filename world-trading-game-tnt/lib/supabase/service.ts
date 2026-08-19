import { createClient } from '@supabase/supabase-js';

export function createServiceClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const key = process.env.SUPABASE_SERVICE_ROLE!;
  if (!url || !key) throw new Error('SUPABASE service environment variables not set');
  return createClient(url, key, {
    auth: { persistSession: false }
  });
}
