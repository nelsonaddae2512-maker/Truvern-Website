// app/loading.tsx
// Global route-level loader for the Truvern app

export default function Loading() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-950 text-slate-100">
      <div className="flex items-center gap-3 text-sm">
        {/* Tiny pulse dot so it feels alive but not annoying */}
        <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
        <span>Loading Truvern...</span>
      </div>
    </div>
  );
}
