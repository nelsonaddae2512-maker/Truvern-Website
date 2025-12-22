// app/issues/page.tsx
import IssuesInbox from "@/components/issues-inbox";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type TabKey = "issues" | "accepted" | "resolved";

function normalizeBool(v: string | string[] | undefined) {
  const s = Array.isArray(v) ? v[0] : v;
  if (!s) return false;
  return s === "1" || s.toLowerCase() === "true" || s.toLowerCase() === "yes";
}

function normalizeTab(v: string | string[] | undefined): TabKey {
  const s = Array.isArray(v) ? v[0] : v;
  if (s === "accepted" || s === "resolved" || s === "issues") return s;
  return "issues";
}

export default async function IssuesPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = (await searchParams) ?? {};
  const showResolved = normalizeBool(sp.showResolved);
  let tab = normalizeTab(sp.tab);
  if (tab === "resolved" && !showResolved) tab = "issues";

  return <IssuesInbox initialTab={tab} showResolved={showResolved} />;
}
