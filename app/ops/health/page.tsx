// app/ops/health/page.tsx
// Truvern Ops Health / Integrity Dashboard

import fs from "fs/promises";
import path from "path";

type SealHealth = {
  check?: string;
  status?: string;
  verified?: boolean;
  checkedAt?: string;
  sealFile?: string;
  storedSeal?: string;
  currentSeal?: string;
  storedFileCount?: number;
  missingFiles?: string[];
};

type TimelineRow = {
  run: number;
  checkedAt: string;
  status: string;
  missing: number;
  sealFile: string;
};

async function loadSealHealth(): Promise<SealHealth | null> {
  try {
    const opsDir = path.join(process.cwd(), "public", "ops", "health");
    const sealPath = path.join(opsDir, "master-seal.json");
    const buf = await fs.readFile(sealPath, "utf8");
    return JSON.parse(buf) as SealHealth;
  } catch {
    return null;
  }
}

function parseTimelineMarkdown(markdown: string): TimelineRow[] {
  const lines = markdown.split(/\r?\n/);

  const tableStartIndex = lines.findIndex((line) =>
    line.startsWith("| Run |")
  );
  if (tableStartIndex === -1) return [];

  const rows: TimelineRow[] = [];
  for (let i = tableStartIndex + 2; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line.startsWith("|")) continue;
    const parts = line.split("|").map((p) => p.trim()).filter(Boolean);
    if (parts.length < 5) continue;

    const [runStr, checkedAt, status, missingStr, sealFile] = parts;

    const run = parseInt(runStr, 10);
    const missing = parseInt(missingStr, 10);

    rows.push({
      run: Number.isNaN(run) ? i : run,
      checkedAt,
      status,
      missing: Number.isNaN(missing) ? 0 : missing,
      sealFile,
    });
  }

  return rows;
}

async function loadTimeline(): Promise<TimelineRow[]> {
  try {
    const opsDir = path.join(process.cwd(), "public", "ops", "health");
    const timelinePath = path.join(opsDir, "integrity-timeline.md");
    const markdown = await fs.readFile(timelinePath, "utf8");
    return parseTimelineMarkdown(markdown);
  } catch {
    return [];
  }
}

export const dynamic = "force-dynamic";

export default async function OpsHealthPage() {
  const [seal, timeline] = await Promise.all([
    loadSealHealth(),
    loadTimeline(),
  ]);

  const statusLabel =
    seal?.status === "pass" && seal?.verified
      ? "Healthy"
      : seal?.status === "pass"
      ? "Pass (unverified)"
      : "Attention needed";

  const statusColor =
    seal?.status === "pass" && seal?.verified
      ? "text-emerald-400"
      : seal?.status === "pass"
      ? "text-amber-400"
      : "text-rose-400";

  const lastChecked = seal?.checkedAt ?? "Unknown";

  const lastRun = timeline[0];

  return (
    <main className="truvern-shell">
      <header className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="truvern-page-heading">Ops Health &amp; Integrity</h1>
          <p className="truvern-page-subheading">
            Master seal status and integrity history for the Truvern platform.
          </p>
        </div>
        <div className="truvern-card flex flex-col gap-1 text-sm">
          <div className="flex items-center justify-between">
            <span className="text-slate-400">Master seal</span>
            <span className={`font-semibold ${statusColor}`}>
              {statusLabel}
            </span>
          </div>
          <div className="flex items-center justify-between text-xs text-slate-400">
            <span>Last checked</span>
            <span className="font-mono">{lastChecked}</span>
          </div>
        </div>
      </header>

      <section className="grid gap-6 md:grid-cols-2">
        {/* Master seal details */}
        <div className="truvern-card flex flex-col gap-3">
          <div className="truvern-card-header">
            <h2 className="truvern-card-title">Master seal details</h2>
          </div>
          {seal ? (
            <dl className="grid grid-cols-1 gap-3 text-sm md:grid-cols-2">
              <div>
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Stored seal hash
                </dt>
                <dd className="font-mono break-all text-xs text-slate-200">
                  {seal.storedSeal ?? "n/a"}
                </dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Current seal hash
                </dt>
                <dd className="font-mono break-all text-xs text-slate-200">
                  {seal.currentSeal ?? "n/a"}
                </dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Seal file
                </dt>
                <dd className="font-mono text-xs text-slate-200">
                  {seal.sealFile ?? "n/a"}
                </dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Files hashed
                </dt>
                <dd className="font-mono text-xs text-slate-200">
                  {seal.storedFileCount ?? "n/a"}
                </dd>
              </div>
              <div className="md:col-span-2">
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Missing files
                </dt>
                <dd className="mt-1">
                  {seal.missingFiles && seal.missingFiles.length > 0 ? (
                    <ul className="list-disc space-y-1 pl-4 text-xs text-amber-300">
                      {seal.missingFiles.map((p) => (
                        <li key={p} className="break-all">
                          {p}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <span className="text-xs text-emerald-400">
                      None reported
                    </span>
                  )}
                </dd>
              </div>
            </dl>
          ) : (
            <p className="text-sm text-slate-400">
              No master seal health file found. Run Phase203, Phase205 and
              Phase208.
            </p>
          )}
        </div>

        {/* Latest integrity run */}
        <div className="truvern-card flex flex-col gap-3">
          <div className="truvern-card-header">
            <h2 className="truvern-card-title">Latest integrity run</h2>
          </div>
          {lastRun ? (
            <dl className="space-y-2 text-sm">
              <div className="flex items-center justify-between gap-4">
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Run
                </dt>
                <dd className="font-mono text-xs text-slate-200">
                  #{lastRun.run}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Checked at
                </dt>
                <dd className="font-mono text-xs text-slate-200">
                  {lastRun.checkedAt}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Status
                </dt>
                <dd className="font-mono text-xs text-slate-200">
                  {lastRun.status}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Missing files
                </dt>
                <dd className="font-mono text-xs text-slate-200">
                  {lastRun.missing}
                </dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wide text-slate-400">
                  Seal file
                </dt>
                <dd className="mt-1 font-mono text-xs text-slate-200 break-all">
                  {lastRun.sealFile}
                </dd>
              </div>
            </dl>
          ) : (
            <p className="text-sm text-slate-400">
              No integrity timeline data available yet. Run Phase207 and then
              Phase208.
            </p>
          )}
        </div>
      </section>

      {/* Full timeline table */}
      <section className="truvern-card">
        <div className="truvern-card-header">
          <h2 className="truvern-card-title">Integrity timeline</h2>
        </div>
        {timeline.length === 0 ? (
          <p className="text-sm text-slate-400">
            No integrity runs captured yet.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="truvern-table text-xs">
              <thead>
                <tr>
                  <th>Run</th>
                  <th>Checked at</th>
                  <th>Status</th>
                  <th>Missing</th>
                  <th>Seal file</th>
                </tr>
              </thead>
              <tbody>
                {timeline.map((row) => (
                  <tr key={row.run}>
                    <td className="font-mono">{row.run}</td>
                    <td className="font-mono">{row.checkedAt}</td>
                    <td>{row.status}</td>
                    <td className="font-mono">{row.missing}</td>
                    <td className="font-mono break-all">{row.sealFile}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
