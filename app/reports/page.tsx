import { ensureArray } from '@/app/lib/safe';
export const dynamic = "force-dynamic";
export const revalidate = 0;
export default function ReportsIndex() {
  return (
    <main style={{padding:"2rem",maxWidth:960,margin:"0 auto"}}>
      <h1>/reports route: ALIVE âœ…</h1>
      <p>This proves the /reports segment renders properly.</p>
      <p><a href="/reports/board?org=demo-2128873b">Go to /reports/board</a></p>
    </main>
  );
}
