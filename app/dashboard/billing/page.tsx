
'use client';
import React from 'react';
import { LineChart, Line, CartesianGrid, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend, BarChart, Bar } from 'recharts';

type UsageSummary = { byDay: Record<string, Record<string, number>>; totals: Record<string, number> };
type BillingSummary = { mrr: number; activeSubscriptions: number };

export default function BillingPage(){
  const [usage, setUsage] = React.useState<UsageSummary | null>(null);
  const [billing, setBilling] = React.useState<BillingSummary | null>(null);

  React.useEffect(()=>{
    (async()=>{
      const u = await fetch('/api/usage/summary'); if(u.ok) setUsage(await u.json());
      const b = await fetch('/api/billing/summary'); if(b.ok) setBilling(await b.json());
    })();
  },[]);

  const data = React.useMemo(()=>{
    if(!usage) return [];
    const keys = Array.from(new Set(Object.values(usage.byDay).flatMap(o=>Object.keys(o))));
    const days = Object.keys(usage.byDay).sort();
    return days.map(d => ({ date: d, ...(keys.reduce((acc,k)=> (acc[k]=usage.byDay[d][k]||0, acc), {} as any)) }));
  }, [usage]);

  const totals = Object.entries(usage?.totals || {}).map(([k,v])=>({ type:k, count:v }));

  return (
    <div className="p-8 space-y-6">
      <h1 className="text-2xl font-bold">Billing & Usage</h1>

      <div className="grid md:grid-cols-3 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-slate-500">MRR (approx)</div>
          <div className="text-3xl font-bold">${billing?.mrr ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-slate-500">Active subscriptions</div>
          <div className="text-3xl font-bold">{billing?.activeSubscriptions ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-slate-500">Top usage type (30d)</div>
          <div className="text-3xl font-bold">{Object.entries(usage?.totals || {}).sort((a,b)=>b[1]-a[1])[0]?.[0] || 'â€”'}</div>
        </div>
      </div>

      <div className="border rounded p-4">
        <div className="text-sm font-semibold mb-2">Usage by Day (30 days)</div>
        <div className="h-[340px]">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={data}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Legend />
              {data.length ? Object.keys(data[0]).filter(k=>k!=='date').map(k=>(
                <Line key={k} type="monotone" dataKey={k} dot={false} />
              )) : null}
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="border rounded p-4">
        <div className="text-sm font-semibold mb-2">Totals by Type (30 days)</div>
        <div className="h-[300px]">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={totals}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="type" />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="count" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}


