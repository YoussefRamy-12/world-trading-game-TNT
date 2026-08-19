import { NextResponse } from 'next/server';
import { createServiceClient } from '@/lib/supabase/service';
import * as XLSX from 'xlsx';

type SheetRow = Record<string, unknown>;

type ValidatedRow = {
  index: number;
  raw: SheetRow;
  result: {
    valid: boolean;
    errors: string[];
    parsed: {
      name: string;
      code: string | null;
      population: number;
      price: number | null;
      income: number | null;
      tier: string | null;
      metadata: Record<string, unknown>;
    };
  };
};

function parseSheet(buffer: ArrayBuffer) {
  const wb = XLSX.read(buffer, { type: 'array' });
  const first = wb.SheetNames[0];
  const ws = wb.Sheets[first];
  const rows = XLSX.utils.sheet_to_json(ws, { defval: null });
  return rows as SheetRow[];
}

function validateRow(r: SheetRow) {
  const errors: string[] = [];
  if (!r.name || String(r.name).trim() === '') errors.push('name_required');

  const incomeRaw = r.income ?? r.Income ?? r.daily_income ?? r.hourly_income ?? r['daily income'];
  const priceRaw = r.price ?? r.Price ?? r.price_usd ?? r['price'];

  const incomeNum = incomeRaw == null || incomeRaw === '' ? null : Number(incomeRaw);
  const priceNum = priceRaw == null || priceRaw === '' ? null : Number(priceRaw);

  if (incomeNum == null || Number.isNaN(incomeNum)) {
    errors.push('income_missing_or_not_number');
  } else if (incomeNum <= 0) {
    errors.push('income_must_be_positive');
  }

  if (priceNum != null && Number.isNaN(priceNum)) {
    errors.push('price_not_number');
  }

  if (r.code && typeof r.code !== 'string') {
    errors.push('code_must_be_string');
  }

  return {
    valid: errors.length === 0,
    errors,
    parsed: {
      name: String(r.name ?? '').trim(),
      code: typeof r.code === 'string' ? r.code : null,
      population: r.population ? Number(r.population) : 0,
      price: priceNum,
      income: incomeNum,
      tier: typeof r.tier === 'string' ? r.tier : typeof r.Tier === 'string' ? r.Tier : null,
      metadata: typeof r.metadata === 'object' && r.metadata !== null ? (r.metadata as Record<string, unknown>) : {},
    },
  };
}

export async function POST(req: Request) {
  const svc = createServiceClient();

  const contentType = req.headers.get('content-type') || '';
  const url = new URL(req.url);
  const confirm = url.searchParams.get('confirm') === 'true';

  if (contentType.includes('multipart/form-data')) {
    const form = await req.formData();
    const file = form.get('file');
    if (!(file instanceof File)) return NextResponse.json({ error: 'file_required' }, { status: 400 });

    const buffer = await file.arrayBuffer();
    const rows = parseSheet(buffer);

    const validated: ValidatedRow[] = rows.map((r, idx) => ({ index: idx + 1, raw: r, result: validateRow(r) }));

    if (!confirm) {
      return NextResponse.json({ preview: validated });
    }

    const invalid = validated.filter((v) => !v.result.valid);
    if (invalid.length > 0) return NextResponse.json({ error: 'validation_failed', details: invalid }, { status: 400 });

    const names = validated.map((v) => v.result.parsed.name);
    const { data: existing } = await svc.from('countries').select('name').in('name', names);
    if (existing && existing.length > 0) {
      return NextResponse.json({ error: 'duplicates_found', existing: existing.map((e: { name: string }) => e.name) }, { status: 400 });
    }

    const toInsert = validated.map((v) => {
      const p = v.result.parsed;
      return {
        name: p.name,
        code: p.code,
        population: p.population || 0,
        game_id: typeof p.metadata.game_id === 'string' ? p.metadata.game_id : null,
        resources: typeof p.metadata.resources === 'object' && p.metadata.resources !== null ? p.metadata.resources : {},
        metadata: {
          price_cents: p.price == null ? null : Math.round(p.price * 100),
          income_cents: p.income == null ? null : Math.round(p.income * 100),
          tier: p.tier,
          imported: true,
        },
      };
    });

    const { data, error } = await svc.from('countries').insert(toInsert).select('id');
    if (error) return NextResponse.json({ error }, { status: 500 });

    return NextResponse.json({ inserted: Array.isArray(data) ? data.length : 0, ids: data });
  }

  return NextResponse.json({ error: 'unsupported_content_type' }, { status: 400 });
}
