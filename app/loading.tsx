import { ensureArray } from '@/app/lib/safe';
export default function Loading() {
  return (
    <div className="flex items-center justify-center py-24">
      <div className="animate-pulse text-sm text-muted-foreground">Loadingâ€¦</div>
    </div>
  );
}
