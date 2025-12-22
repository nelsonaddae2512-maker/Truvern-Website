// app/(clerk)/layout.tsx
import AppShell from "../app-shell";

export const runtime = "nodejs";

export default function ClerkLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <AppShell>
      <div className="min-h-screen flex items-center justify-center px-4 py-10">
        {children}
      </div>
    </AppShell>
  );
}
