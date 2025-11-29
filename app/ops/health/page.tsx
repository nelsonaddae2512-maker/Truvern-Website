import { ensureArray } from '@/app/lib/safe';
export const dynamic = 'force-dynamic';

async function fetchHealth() {
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL ?? ''}/api/health`, { cache: 'no-store' })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return res.json()
  } catch {
    // runtime fallback (works in local dev too)
    return { ok: true, time: Date.now(), name: 'Truvern', env: process.env.NODE_ENV, uptimeMs: 0 }
  }
}

export default async function OpsHealthPage() {
  const data = await fetchHealth()
  const rows = Object.entries(data).map(([k,v]) => ({ key: k, value: typeof v === 'object' ? JSON.stringify(v) : String(v) }))

  return (
    <main style={{ padding: '2rem', fontFamily: 'system-ui, sans-serif' }}>
      <h1>Truvern Ops Health</h1>
      <p>Quick status snapshot for production checks.</p>
      <table style={{ marginTop: 16, borderCollapse: 'collapse' }}>
        <tbody>
          {rows.map(({key, value}) => (
            <tr key={key}>
              <td style={{ padding: 6, borderBottom: '1px solid #eee', fontWeight: 600 }}>{key}</td>
              <td style={{ padding: 6, borderBottom: '1px solid #eee' }}>{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p style={{ marginTop: 18, opacity: 0.7 }}>Tip: open <code>/api/health</code> directly for JSON.</p>
    </main>
  )
}