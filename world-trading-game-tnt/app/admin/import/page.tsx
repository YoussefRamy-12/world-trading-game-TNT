"use client";
import { useState } from 'react';

type PreviewRow = {
  index: number;
  raw: Record<string, unknown>;
  result: {
    valid: boolean;
    errors: string[];
  };
};

export default function ImportCountriesPage(){
  const [input, setInput] = useState('');
  const [status, setStatus] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<PreviewRow[] | null>(null);
  const [errors, setErrors] = useState<PreviewRow[] | null>(null);
  const [loading, setLoading] = useState(false);

  async function submitJson(){
    setStatus('Importing...');
    try{
      const payload = JSON.parse(input);
      const res = await fetch('/api/admin/import-countries', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ countries: payload }) });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || 'Import failed');
      setStatus(`Imported ${data.inserted} countries`);
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      setStatus('Error: ' + message);
    }
  }

  async function previewFile() {
    if (!file) return setStatus('No file selected');
    setLoading(true);
    setStatus('Parsing file...');
    const fd = new FormData();
    fd.append('file', file);
    try{
      const res = await fetch('/api/admin/import-countries-file', { method: 'POST', body: fd });
      const data = await res.json();
      if (!res.ok) {
        setStatus('Error: ' + (data?.error || 'Preview failed'));
        setLoading(false);
        return;
      }
      setPreview(data.preview || []);
      setErrors(data.preview ? data.preview.filter((p: PreviewRow) => !p.result.valid) : []);
      setStatus('Preview ready');
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      setStatus('Error: ' + message);
    }
    setLoading(false);
  }

  async function confirmFile() {
    if (!file) return setStatus('No file selected');
    setLoading(true);
    setStatus('Importing...');
    const fd = new FormData();
    fd.append('file', file);
    try{
      const res = await fetch('/api/admin/import-countries-file?confirm=true', { method: 'POST', body: fd });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || 'Import failed');
      setStatus(`Imported ${data.inserted} countries`);
      setPreview(null);
      setFile(null);
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      setStatus('Error: ' + message);
    }
    setLoading(false);
  }

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <input type="file" accept=".csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel" onChange={(e)=>setFile(e.target.files?.[0]??null)} className="p-1" />
        <button onClick={previewFile} disabled={loading} className="rounded bg-amber-500 px-4 py-2">Preview file</button>
        <button onClick={confirmFile} disabled={!preview || (errors && errors.length>0) || loading} className="rounded bg-emerald-500 px-4 py-2">Confirm import</button>
      </div>

      <div className="my-3">
        <p className="text-sm text-slate-400">Or paste JSON array:</p>
        <textarea value={input} onChange={(e)=>setInput(e.target.value)} className="w-full min-h-[120px] rounded p-2 bg-slate-800 text-slate-50" placeholder='[ { "name": "Egypt", "code": "EG", "population": 1000000, "game_id": "..." } ]' />
        <div className="flex gap-2 mt-2">
          <button onClick={submitJson} className="rounded bg-emerald-500 px-4 py-2">Import JSON</button>
          <button onClick={()=>{ setInput(''); setStatus(null); }} className="rounded border px-4 py-2">Clear</button>
        </div>
      </div>

      {status && <div className="mt-2 text-sm">{status}</div>}

      {preview && (
        <div className="mt-4">
          <h3 className="font-semibold">Preview ({preview.length} rows)</h3>
          <div className="mt-2 space-y-2 text-sm max-h-80 overflow-auto">
            {preview.slice(0,200).map((p: PreviewRow)=> (
              <div key={p.index} className={`rounded p-2 ${p.result.valid ? 'bg-slate-800' : 'bg-rose-900/60'}`}>
                <div className="font-medium">{String((p.raw.name ?? p.raw.Name ?? `Row ${p.index}`))}</div>
                <div className="text-xs text-slate-400">{JSON.stringify(p.raw)}</div>
                {!p.result.valid && <div className="text-xs text-rose-300">Errors: {p.result.errors.join(', ')}</div>}
              </div>
            ))}
          </div>
        </div>
      )}

    </div>
  );
}
