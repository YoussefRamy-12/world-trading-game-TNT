import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export const metadata = {
  title: "Admin",
};

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;

  if (!claims) {
    redirect('/auth/login');
  }

  // check players.is_admin
  const userId = claims?.sub || claims?.user_id || null;
  if (!userId) redirect('/auth/login');

  const { data: playerRow, error: pe } = await supabase
    .from('players')
    .select('is_admin')
    .eq('id', userId)
    .limit(1)
    .single();

  if (pe || !playerRow || !playerRow.is_admin) {
    redirect('/');
  }

  return (
    <div className="min-h-screen bg-slate-900 text-slate-50">
      <div className="mx-auto max-w-6xl p-6">
        <header className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-bold">Admin Panel</h1>
        </header>
        <main>{children}</main>
      </div>
    </div>
  );
}
