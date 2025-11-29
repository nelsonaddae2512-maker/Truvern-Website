"use client";
import React from "react";
type Vendor={id?:string|number;name?:string}; type Board={generatedAt?:string;vendors?:Vendor[]};
async function j<T>(u:string){try{const r=await fetch(u,{cache:'no-store'});return r.ok?await r.json():null}catch{return null}}
export default function HomeClient(){
  const [vendors,setV]=React.useState<Vendor[]>([]); const [board,setB]=React.useState<Board|null>(null); const [loading,setL]=React.useState(true);
  React.useEffect(()=>{let on=true;(async()=>{const v=await j<any>('/api/vendors'); const b=await j<Board>('/api/board'); if(!on)return;
    setV(Array.isArray(v?.vendors)?v.vendors:(Array.isArray(v)?v:[])??[]); setB(b??null); setL(false)})(); return()=>{on=false}},[]);
  const count=vendors.length;
  return (<div className="space-y-6">
    <section><h1 className="text-3xl font-bold">Trust your vendors.</h1><p className="text-zinc-600 mt-2">Move faster with confidence.</p></section>
    <section className="border rounded-xl p-4 flex items-center gap-4">
      <div className="font-medium">Vendors</div><div className="px-3 py-1 border rounded-full font-mono">{count}</div>
      <div className="text-zinc-500 text-sm">total</div>{board?.generatedAt&&<div className="ml-auto text-xs text-zinc-500">generated {new Date(board.generatedAt).toLocaleString()}</div>}
    </section>
    <div className="grid sm:grid-cols-2 gap-4">
      <a className="border rounded-lg p-4 hover:bg-zinc-50" href="/trust-network"><div className="font-semibold">Open Trust Network</div><div className="text-sm text-zinc-600">Browse and compare vendors</div></a>
      <a className="border rounded-lg p-4 hover:bg-zinc-50" href="/reports/board"><div className="font-semibold">Open Board Report</div><div className="text-sm text-zinc-600">Summary & CSV export</div></a>
    </div>
  </div>);
}