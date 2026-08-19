import Link from "next/link";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

const players = [
  { name: "Player A", flag: "🇪🇬", score: 12450, status: "Ready" },
  { name: "Player B", flag: "🇫🇷", score: 11680, status: "In game" },
  { name: "Player C", flag: "🇬🇧", score: 10910, status: "Ready" },
  { name: "Player D", flag: "🇯🇵", score: 9840, status: "Away" },
];

const countries = [
  { name: "Egypt", flag: "🇪🇬", owner: "You", value: 12450, income: 620, tier: "Gold" },
  { name: "France", flag: "🇫🇷", owner: "Player B", value: 11840, income: 560, tier: "Gold" },
  { name: "UK", flag: "🇬🇧", owner: "Player C", value: 10190, income: 470, tier: "Silver" },
  { name: "Japan", flag: "🇯🇵", owner: "Player D", value: 9420, income: 430, tier: "Silver" },
];

const listings = [
  { country: "Egypt", seller: "Player A", price: "$8,400", bid: "$7,900", status: "Open" },
  { country: "Brazil", seller: "Player C", price: "$6,300", bid: "$5,800", status: "Open" },
  { country: "Canada", seller: "Player D", price: "$5,900", bid: "$4,700", status: "Bid" },
];

const leaderboard = [
  { rank: 1, player: "Player A", netWorth: "$12,450", trend: "+$1,200" },
  { rank: 2, player: "Player B", netWorth: "$11,680", trend: "+$980" },
  { rank: 3, player: "Player C", netWorth: "$10,910", trend: "+$730" },
  { rank: 4, player: "Player D", netWorth: "$9,840", trend: "+$610" },
];

const tabs = ["My Countries", "Market", "Ranking"] as const;

export function GameDashboard() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto max-w-7xl px-4 py-6">
        <header className="mb-6 flex flex-col gap-4 rounded-2xl border border-white/10 bg-slate-900/80 p-4 shadow-2xl shadow-slate-950/40 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.3em] text-cyan-300">World Trading Game</p>
            <h1 className="mt-1 text-2xl font-bold">Global Economic Strategy</h1>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-sm text-emerald-200">
              Cash: <span className="font-bold">$12,450</span>
            </div>
            <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-sm text-amber-200">
              Reputation: <span className="font-bold">⭐ 320</span>
            </div>
            <div className="rounded-lg border border-sky-500/30 bg-sky-500/10 px-3 py-2 text-sm text-sky-200">
              Day <span className="font-bold">2</span>
            </div>
            <Link href="/auth/login">
              <Button variant="outline" className="border-white/15 bg-white/5 text-white hover:bg-white/10">
                Login
              </Button>
            </Link>
          </div>
        </header>

        <section className="mb-6 grid gap-4 md:grid-cols-[1.4fr_0.6fr]">
          <Card className="border-white/10 bg-slate-900/80">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-xl">World Map</CardTitle>
                  <CardDescription>Live country ownership and market activity.</CardDescription>
                </div>
                <div className="rounded-full border border-cyan-500/40 bg-cyan-500/10 px-3 py-1 text-xs font-medium text-cyan-200">
                  Game running
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="relative overflow-hidden rounded-2xl border border-white/10 bg-[radial-gradient(circle_at_top,_rgba(14,165,233,0.16),_transparent_50%),linear-gradient(135deg,#0f172a,#111827_40%,#0b1120)] p-6">
                <div className="absolute left-[8%] top-[20%] h-14 w-14 rounded-full border border-cyan-300/30 bg-cyan-500/10" />
                <div className="absolute right-[18%] top-[25%] h-14 w-14 rounded-full border border-emerald-300/30 bg-emerald-500/10" />
                <div className="absolute left-[36%] bottom-[18%] h-14 w-14 rounded-full border border-amber-300/30 bg-amber-500/10" />
                <div className="absolute right-[28%] bottom-[24%] h-14 w-14 rounded-full border border-fuchsia-300/30 bg-fuchsia-500/10" />

                <div className="relative flex min-h-[240px] items-center justify-center">
                  <div className="flex flex-wrap items-center justify-center gap-4 text-2xl md:gap-6">
                    {countries.map((country) => (
                      <div key={country.name} className="rounded-full border border-white/10 bg-slate-900/60 px-4 py-2 shadow-lg shadow-slate-950/40">
                        <span>{country.flag}</span>
                        <span className="ml-2 text-sm font-medium text-slate-100">{country.name}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="border-white/10 bg-slate-900/80">
            <CardHeader>
              <CardTitle>Lobby</CardTitle>
              <CardDescription>Players and game status</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {players.map((player) => (
                <div key={player.name} className="flex items-center justify-between rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2">
                  <div className="flex items-center gap-3">
                    <div className="text-xl">{player.flag}</div>
                    <div>
                      <p className="font-medium text-white">{player.name}</p>
                      <p className="text-xs text-slate-400">{player.status}</p>
                    </div>
                  </div>
                  <div className="text-sm font-semibold text-cyan-300">${player.score.toLocaleString()}</div>
                </div>
              ))}
            </CardContent>
          </Card>
        </section>

        <section className="mb-6 grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
          <Card className="border-white/10 bg-slate-900/80">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Country details</CardTitle>
                  <CardDescription>Egypt • Tier: Gold • Daily income: $620</CardDescription>
                </div>
                <div className="flex items-center gap-1 text-amber-300">
                  {Array.from({ length: 3 }).map((_, idx) => (
                    <span key={idx}>⭐</span>
                  ))}
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-5">
              <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                <div className="rounded-xl border border-white/10 bg-slate-950/60 p-3">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Price</p>
                  <p className="mt-2 text-xl font-semibold text-white">$8,400</p>
                </div>
                <div className="rounded-xl border border-white/10 bg-slate-950/60 p-3">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Income</p>
                  <p className="mt-2 text-xl font-semibold text-emerald-300">$620 / hr</p>
                </div>
                <div className="rounded-xl border border-white/10 bg-slate-950/60 p-3">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Owner</p>
                  <p className="mt-2 text-xl font-semibold text-cyan-300">You</p>
                </div>
                <div className="rounded-xl border border-white/10 bg-slate-950/60 p-3">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Buildings</p>
                  <p className="mt-2 text-xl font-semibold text-white">4 / 6</p>
                </div>
              </div>

              <div className="flex flex-wrap gap-3">
                <Button className="bg-emerald-500 text-emerald-950 hover:bg-emerald-400">BUY</Button>
                <Button variant="secondary">UPGRADE</Button>
                <Button variant="outline">LIST</Button>
                <Button variant="outline">BID</Button>
              </div>
            </CardContent>
          </Card>

          <Card className="border-white/10 bg-slate-900/80">
            <CardHeader>
              <CardTitle>My Countries</CardTitle>
              <CardDescription>Selected nation portfolio</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {countries.map((country) => (
                <div key={country.name} className="flex items-center justify-between rounded-xl border border-white/10 bg-slate-950/60 px-3 py-3">
                  <div className="flex items-center gap-3">
                    <div className="text-2xl">{country.flag}</div>
                    <div>
                      <p className="font-medium text-white">{country.name}</p>
                      <p className="text-xs text-slate-400">{country.owner}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold text-cyan-300">${country.value.toLocaleString()}</p>
                    <p className="text-xs text-emerald-300">+${country.income}/hr</p>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </section>

        <section className="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
          <Card className="border-white/10 bg-slate-900/80">
            <CardHeader>
              <CardTitle>Marketplace</CardTitle>
              <CardDescription>Available listings, my bids, and open offers</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {listings.map((listing) => (
                  <div key={listing.country} className="flex items-center justify-between rounded-xl border border-white/10 bg-slate-950/60 px-3 py-3">
                    <div>
                      <p className="font-medium text-white">{listing.country}</p>
                      <p className="text-xs text-slate-400">Seller: {listing.seller}</p>
                    </div>
                    <div className="flex items-center gap-4">
                      <div className="text-right">
                        <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Price</p>
                        <p className="font-semibold text-cyan-300">{listing.price}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Bid</p>
                        <p className="font-semibold text-emerald-300">{listing.bid}</p>
                      </div>
                      <div className="rounded-full border border-white/10 bg-white/5 px-2 py-1 text-xs uppercase tracking-[0.2em] text-slate-200">
                        {listing.status}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card className="border-white/10 bg-slate-900/80">
            <CardHeader>
              <CardTitle>Leaderboard</CardTitle>
              <CardDescription>Top players by net worth</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {leaderboard.map((entry) => (
                <div key={entry.rank} className="flex items-center justify-between rounded-xl border border-white/10 bg-slate-950/60 px-3 py-3">
                  <div className="flex items-center gap-3">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-cyan-500/15 font-bold text-cyan-300">
                      {entry.rank}
                    </div>
                    <div>
                      <p className="font-medium text-white">{entry.player}</p>
                      <p className="text-xs text-emerald-300">{entry.trend}</p>
                    </div>
                  </div>
                  <div className="font-semibold text-cyan-300">{entry.netWorth}</div>
                </div>
              ))}
            </CardContent>
          </Card>
        </section>

        <footer className="mt-6 flex items-center justify-between rounded-2xl border border-white/10 bg-slate-900/80 p-4 text-sm text-slate-300">
          <div className="flex gap-3">
            {tabs.map((tab) => (
              <button key={tab} className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 hover:bg-white/10">
                {tab}
              </button>
            ))}
          </div>
          <p>Realtime: <span className="font-semibold text-emerald-300">Live</span></p>
        </footer>
      </div>
    </main>
  );
}
