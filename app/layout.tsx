import "./globals.css";
import { ClerkProvider } from "@clerk/nextjs";
import SiteHeader from "@/components/site-header";
import AppShell from "./app-shell";

export const runtime = "nodejs";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="text-slate-100">
        <ClerkProvider>
          <AppShell>
            <div className="min-h-screen">
              <SiteHeader />
              {children}
            </div>
          </AppShell>
        </ClerkProvider>
      </body>
    </html>
  );
}
