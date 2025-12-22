"use client";

import { useEffect, useState, FormEvent, ChangeEvent } from "react";
import Link from "next/link";
import VendorEvidenceTimeline from "@/components/vendor-evidence-timeline";

type Vendor = {
  id: number;
  name: string;
  riskScore: number | null;
  createdAt: string | null;
};

const EVIDENCE_KIND_OPTIONS = [
  { value: "REPORT", label: "Report" },
  { value: "POLICY", label: "Policy" },
  { value: "CERTIFICATE", label: "Certificate" },
  { value: "SCREENSHOT", label: "Screenshot" },
  { value: "OTHER", label: "Other" },
];

export default function VendorsPage() {
  const [vendors, setVendors] = useState<Vendor[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState("");
  const [riskScore, setRiskScore] = useState<string>("");

  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);

  const [selectedVendor, setSelectedVendor] = useState<Vendor | null>(null);

  // Vendor search
  const [vendorSearch, setVendorSearch] = useState("");

  // Upload state
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [uploadTitle, setUploadTitle] = useState("");
  const [uploadKind, setUploadKind] = useState<string>("REPORT");
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  // Vendor delete state
  const [vendorDeleting, setVendorDeleting] = useState(false);
  const [vendorDeleteError, setVendorDeleteError] = useState<string | null>(
    null
  );

  // let timeline know when to refresh
  const [evidenceRefreshKey, setEvidenceRefreshKey] = useState(0);

  // Load vendors (only non-deleted; API handles that)
  async function loadVendors() {
    try {
      setLoading(true);
      setError(null);

      const res = await fetch("/api/vendors", { cache: "no-store" });

      const raw = await res.text();
      let data: any = {};
      if (raw) {
        try {
          data = JSON.parse(raw);
        } catch {
          // raw wasn't JSON, leave data as {}
        }
      }

      if (!res.ok) {
        const msg =
          (data && (data.error as string)) ||
          raw.trim() ||
          `Failed to load vendors (HTTP ${res.status}).`;
        throw new Error(msg);
      }

      const list: Vendor[] = Array.isArray(data)
        ? data
        : Array.isArray(data.vendors)
        ? data.vendors
        : [];

      setVendors(list);

      if (!selectedVendor && list.length > 0) {
        setSelectedVendor(list[0]);
      } else if (
        selectedVendor &&
        !list.some((v) => v.id === selectedVendor.id)
      ) {
        // selected vendor was deleted, pick first remaining or null
        setSelectedVendor(list[0] ?? null);
      }
    } catch (e: any) {
      setError(e?.message ?? "Failed to load vendors.");
      setVendors([]);
      setSelectedVendor(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadVendors();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleCreateVendor(e: FormEvent) {
    e.preventDefault();

    if (!name.trim()) {
      setCreateError("Vendor name is required.");
      return;
    }

    setCreating(true);
    setCreateError(null);

    try {
      const res = await fetch("/api/vendors/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          riskScore:
            riskScore === "" || riskScore == null ? null : Number(riskScore),
        }),
      });

      const raw = await res.text();
      let data: any = {};
      if (raw) {
        try {
          data = JSON.parse(raw);
        } catch {
          throw new Error(
            raw.trim() || "Server returned an invalid response."
          );
        }
      }

      if (!res.ok) {
        throw new Error(data.error || "Failed to create vendor.");
      }

      const newVendor: Vendor = data.vendor;

      setName("");
      setRiskScore("");

      await loadVendors();
      setSelectedVendor(newVendor);
      setVendorSearch(""); // reset search after create
    } catch (err: any) {
      setCreateError(err?.message ?? "Failed to create vendor.");
    } finally {
      setCreating(false);
    }
  }

  function handleFileChange(e: ChangeEvent<HTMLInputElement>) {
    if (!e.target.files || e.target.files.length === 0) {
      setUploadFile(null);
      return;
    }
    setUploadFile(e.target.files[0]);
  }

  async function handleUploadEvidence(e: FormEvent) {
    e.preventDefault();

    if (!selectedVendor) {
      setUploadError("Select a vendor first.");
      return;
    }
    if (!uploadFile) {
      setUploadError("Choose a file to upload.");
      return;
    }

    setUploading(true);
    setUploadError(null);

    try {
      const file = uploadFile;

      const res = await fetch("/api/evidence/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          vendorId: selectedVendor.id,
          title: uploadTitle || file.name,
          fileName: file.name,
          kind: uploadKind,
        }),
      });

      const raw = await res.text();
      let data: any = {};
      if (raw) {
        try {
          data = JSON.parse(raw);
        } catch {
          throw new Error(
            raw.trim() || "Server returned an invalid response."
          );
        }
      }

      if (!res.ok) {
        throw new Error(data.error || "Failed to upload evidence.");
      }

      setUploadTitle("");
      setUploadFile(null);
      setUploadKind("REPORT");

      // tell timeline to refresh
      setEvidenceRefreshKey((k) => k + 1);
    } catch (err: any) {
      setUploadError(err?.message ?? "Failed to upload evidence.");
    } finally {
      setUploading(false);
    }
  }

  async function handleDeleteVendor() {
    if (!selectedVendor) return;

    const confirmed = window.confirm(
      `Delete vendor "${selectedVendor.name}"? This will permanently delete the vendor once all evidence is removed.`
    );
    if (!confirmed) return;

    setVendorDeleting(true);
    setVendorDeleteError(null);

    try {
      const res = await fetch(`/api/vendors/${selectedVendor.id}`, {
        method: "DELETE",
      });

      let data: any = null;
      try {
        const raw = await res.text();
        if (raw) data = JSON.parse(raw);
      } catch {
        // ignore parse errors
      }

      if (!res.ok) {
        throw new Error(
          data?.error || "Failed to delete vendor. Please try again."
        );
      }

      await loadVendors();
      // evidence timeline will automatically switch to new selected vendor or none
      setEvidenceRefreshKey((k) => k + 1);
    } catch (err: any) {
      setVendorDeleteError(err?.message ?? "Failed to delete vendor.");
    } finally {
      setVendorDeleting(false);
    }
  }

  // Client-side vendor filtering
  const searchTerm = vendorSearch.trim().toLowerCase();
  const filteredVendors =
    searchTerm.length === 0
      ? vendors
      : vendors.filter((v) => v.name.toLowerCase().includes(searchTerm));

  return (
    <main className="min-h-screen px-6 py-10 mx-auto max-w-6xl text-slate-50">
      <header className="mb-8">
        <h1 className="text-3xl font-semibold">Vendors</h1>
        <p className="text-sm text-slate-400 mt-1">
          Manage vendors and upload evidence in one workspace.
        </p>
      </header>

      <div className="grid gap-6 md:grid-cols-[minmax(0,2fr)_minmax(0,1.5fr)]">
        {/* LEFT: Vendor list + create */}
        <section className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
          <div className="flex items-center justify-between gap-3 mb-4">
            <h2 className="text-lg font-medium">Your vendors</h2>
            <div className="relative w-64 max-w-full">
              <input
                className="w-full rounded-full border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs outline-none focus:border-emerald-400"
                placeholder="Search vendors by name…"
                value={vendorSearch}
                onChange={(e) => setVendorSearch(e.target.value)}
              />
            </div>
          </div>

          {loading ? (
            <p className="text-sm text-slate-400">Loading vendors…</p>
          ) : error ? (
            <p className="text-sm text-red-400">{error}</p>
          ) : vendors.length === 0 ? (
            <p className="text-sm text-slate-400 mb-4">
              No vendors yet. Add your first vendor below.
            </p>
          ) : filteredVendors.length === 0 ? (
            <p className="text-sm text-slate-400 mb-4">
              No vendors match “{vendorSearch.trim()}”.
            </p>
          ) : (
            <table className="w-full text-sm border-collapse mb-6">
              <thead>
                <tr className="text-slate-400 border-b border-slate-800">
                  <th className="text-left py-2 pr-4 font-normal">Name</th>
                  <th className="text-left py-2 pr-4 font-normal">
                    Risk score
                  </th>
                  <th className="text-left py-2 font-normal">Created</th>
                </tr>
              </thead>
              <tbody>
                {filteredVendors.map((v) => {
                  const isSelected = selectedVendor?.id === v.id;
                  return (
                    <tr
                      key={v.id}
                      className={`border-b border-slate-900/60 last:border-0 cursor-pointer ${
                        isSelected ? "bg-slate-800/50" : ""
                      }`}
                      onClick={() => setSelectedVendor(v)}
                    >
                      <td className="py-2 pr-4">
                        <span className="hover:text-emerald-300">
                          {v.name}
                        </span>
                      </td>
                      <td className="py-2 pr-4">
                        {v.riskScore === null || v.riskScore === undefined
                          ? "—"
                          : v.riskScore}
                      </td>
                      <td className="py-2 pr-4">
                        {v.createdAt
                          ? new Date(v.createdAt).toLocaleDateString()
                          : "—"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}

          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-medium text-slate-200">Add vendor</h3>
            <button
              onClick={loadVendors}
              className="text-xs rounded-full border border-slate-700 px-3 py-1 hover:border-emerald-400"
            >
              Refresh list
            </button>
          </div>

          <form
            onSubmit={handleCreateVendor}
            className="flex flex-col gap-4 max-w-xl"
          >
            <div>
              <label className="block text-sm mb-1 text-slate-300">
                Vendor name
              </label>
              <input
                className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm outline-none focus:border-emerald-400"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Autos Place"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-300">
                Initial risk score (optional)
              </label>
              <input
                className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm outline-none focus:border-emerald-400"
                value={riskScore}
                onChange={(e) => setRiskScore(e.target.value)}
                placeholder="0–100"
                inputMode="numeric"
              />
            </div>

            {createError && (
              <p className="text-sm text-red-400">{createError}</p>
            )}

            <button
              type="submit"
              disabled={creating}
              className="inline-flex items-center justify-center rounded-full bg-emerald-500 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60"
            >
              {creating ? "Creating…" : "Create vendor"}
            </button>
          </form>
        </section>

        {/* RIGHT: Vendor workspace */}
        <section className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
          <h2 className="text-lg font-medium mb-4">Vendor workspace</h2>

          {!selectedVendor ? (
            <p className="text-sm text-slate-400">
              Select a vendor on the left to view details and upload evidence.
            </p>
          ) : (
            <>
              <div className="mb-6 flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-base font-semibold">
                    {selectedVendor.name}
                  </h3>
                  <p className="text-xs text-slate-400 mt-1">
                    Created{" "}
                    {selectedVendor.createdAt
                      ? new Date(
                          selectedVendor.createdAt
                        ).toLocaleDateString()
                      : "—"}
                    {" · "}
                    {selectedVendor.riskScore != null
                      ? `Risk score ${selectedVendor.riskScore}`
                      : "Risk score not set"}
                  </p>

                  {/* NEW: View trust profile + vendor workspace buttons */}
                  <div className="mt-3 flex flex-wrap gap-3">
                    <Link
                      href={`/trust/${selectedVendor.id}`}
                      className="rounded-full border border-slate-700 bg-slate-900 px-4 py-1.5 text-xs font-medium text-slate-50 hover:border-emerald-400 hover:bg-slate-800"
                    >
                      View trust profile
                    </Link>
                    <Link
                      href={`/vendors/${selectedVendor.id}`}
                      className="rounded-full border border-slate-700 bg-slate-900 px-4 py-1.5 text-xs font-medium text-slate-50 hover:border-emerald-400 hover:bg-slate-800"
                    >
                      View vendor workspace
                    </Link>
                  </div>
                </div>

                <div className="flex flex-col items-end gap-1">
                  {vendorDeleteError && (
                    <p className="text-[10px] text-red-400 text-right max-w-xs">
                      {vendorDeleteError}
                    </p>
                  )}
                  <button
                    type="button"
                    onClick={handleDeleteVendor}
                    disabled={vendorDeleting}
                    className="mt-1 inline-flex items-center rounded-full border border-red-500 px-3 py-1 text-[11px] text-red-200 hover:bg-red-500/10 disabled:opacity-60"
                  >
                    {vendorDeleting ? "Deleting…" : "Delete vendor"}
                  </button>
                </div>
              </div>

              <div className="mb-6">
                <h4 className="text-sm font-medium mb-2">
                  Upload evidence (temporary placeholder)
                </h4>
                <form
                  onSubmit={handleUploadEvidence}
                  className="flex flex-col gap-3"
                >
                  <div>
                    <label className="block text-xs mb-1 text-slate-300">
                      Evidence title (optional)
                    </label>
                    <input
                      className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs outline-none focus:border-emerald-400"
                      value={uploadTitle}
                      onChange={(e) => setUploadTitle(e.target.value)}
                      placeholder="e.g. SOC 2 report 2025"
                    />
                  </div>

                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                    <div className="flex-1">
                      <label className="block text-xs mb-1 text-slate-300">
                        File
                      </label>
                      <input
                        type="file"
                        onChange={handleFileChange}
                        className="w-full text-xs text-slate-300"
                      />
                    </div>

                    <div className="sm:w-48">
                      <label className="block text-xs mb-1 text-slate-300">
                        Evidence type
                      </label>
                      <select
                        className="w-full rounded-xl border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs outline-none focus:border-emerald-400"
                        value={uploadKind}
                        onChange={(e) => setUploadKind(e.target.value)}
                      >
                        {EVIDENCE_KIND_OPTIONS.map((opt) => (
                          <option key={opt.value} value={opt.value}>
                            {opt.label}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>

                  {uploadError && (
                    <p className="text-xs text-red-400">{uploadError}</p>
                  )}

                  <button
                    type="submit"
                    disabled={uploading}
                    className="inline-flex items-center justify-center rounded-full bg-emerald-500 px-4 py-1.5 text-xs font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60"
                  >
                    {uploading ? "Uploading…" : "Upload evidence"}
                  </button>
                </form>
              </div>

              {/* Shared evidence timeline */}
              <VendorEvidenceTimeline
                vendorId={selectedVendor.id}
                vendorName={selectedVendor.name}
                refreshKey={evidenceRefreshKey}
              />
            </>
          )}
        </section>
      </div>
    </main>
  );
}
