// app/error.tsx
"use client";

export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  console.error(error);

  return (
    <div className="truvern-shell">
      <h1 className="truvern-page-heading">Something went wrong</h1>
      <p className="truvern-page-subheading">
        {error?.message ?? "Unexpected error"}
      </p>

      <div className="mt-4 flex gap-3">
        <button
          type="button"
          onClick={() => reset()}
          className="btn-primary"
        >
          Try again
        </button>

        <a href="/" className="btn-outline">
          Back home
        </a>
      </div>
    </div>
  );
}
