'use client';
import React from 'react';
export default function DarkModeToggle(){
  const [mounted,setMounted]=React.useState(false);
  React.useEffect(()=>setMounted(true),[]);
  React.useEffect(()=>{
    const prefers = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const saved = localStorage.getItem('theme');
    const dark = saved ? saved==='dark' : prefers;
    document.documentElement.classList.toggle('dark', dark);
  },[]);
  if(!mounted) return null;
  const onToggle = ()=> {
    const isDark = document.documentElement.classList.toggle('dark');
    localStorage.setItem('theme', isDark ? 'dark' : 'light');
  };
  return <button onClick={onToggle} className="text-sm px-3 py-2 rounded border dark:border-zinc-700">Toggle Theme</button>;
}