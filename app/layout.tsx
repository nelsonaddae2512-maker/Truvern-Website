// app/layout.tsx
import "./globals.css";
import type { ReactNode } from "react";
import { ClerkProvider } from "@clerk/nextjs";
import SiteHeader from "@/components/site-header";

export const metadata = {
  title: "Truvern",
  description: "Vendor risk you can actually trust.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body
          className="bg-slate-950 text-slate-50 min-h-screen print:bg-white print:text-slate-900 print:p-0"
          suppressHydrationWarning={true}
        >
          <div className="min-h-screen flex flex-col">
            <header className="print:hidden">
              <SiteHeader />
            </header>

            <main className="flex-1">
              {children}
            </main>
          </div>
        </body>
      </html>
    </ClerkProvider>
  );
}
