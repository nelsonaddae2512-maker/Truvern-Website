// app/components/EvidenceDeleteButton.tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export function EvidenceDeleteButton({ evidenceId }: { evidenceId: number }) {
  const router = useRouter();
  const [deleting, setDeleting] = useState(false);

  async function handleDelete() {
    if (deleting) return;

    const confirmed = window.confirm(
      "Are you sure you want to delete this evidence? This action cannot be undone."
    );
    if (!confirmed) return;

    setDeleting(true);
    try {
      const res = await fetch(`/api/evidence/${evidenceId}`, {
        method: "DELETE",
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        const msg =
          data?.error ||
          `Delete failed with status ${res.status}. Please try again.`;
        alert(msg);
        setDeleting(false);
        return;
      }

      // Refresh the vendor page so the row disappears
      router.refresh();
    } catch (err) {
      console.error("Error deleting evidence:", err);
      alert("Unexpected error while deleting evidence.");
      setDeleting(false);
    }
  }

  return (
    <button
      type="button"
      onClick={handleDelete}
      disabled={deleting}
      className="text-xs font-medium text-rose-400 hover:text-rose-300 disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {deleting ? "Deleting…" : "Delete"}
    </button>
  );
}
