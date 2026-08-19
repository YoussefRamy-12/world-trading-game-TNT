import Link from 'next/link';

export default function AdminHome() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        <Link href="/admin/games" className="rounded border p-4 hover:bg-white/5">Games</Link>
        <Link href="/admin/players" className="rounded border p-4 hover:bg-white/5">Players</Link>
        <Link href="/admin/countries" className="rounded border p-4 hover:bg-white/5">Countries</Link>
        <Link href="/admin/buildings" className="rounded border p-4 hover:bg-white/5">Buildings</Link>
        <Link href="/admin/marketplace" className="rounded border p-4 hover:bg-white/5">Marketplace</Link>
        <Link href="/admin/transactions" className="rounded border p-4 hover:bg-white/5">Transactions</Link>
        <Link href="/admin/events" className="rounded border p-4 hover:bg-white/5">Events</Link>
        <Link href="/admin/leaderboard" className="rounded border p-4 hover:bg-white/5">Leaderboard</Link>
        <Link href="/admin/settings" className="rounded border p-4 hover:bg-white/5">Settings</Link>
      </div>

      <div>
        <h2 className="text-xl font-semibold">Import Countries</h2>
        <p className="text-sm text-slate-300">Upload JSON array of countries or paste JSON into the importer.</p>
        <div className="mt-3">
          <Link href="/admin/import" className="rounded bg-cyan-600 px-4 py-2 text-white">Open Importer</Link>
        </div>
      </div>
    </div>
  );
}
