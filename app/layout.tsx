
import React from "react";
import SessionWrap from "@/components/providers/Session";
import "./globals.css";
import { I18nProvider } from "../lib/i18n";
export const metadata = {
  metadataBase: new URL("https://truvern.com"),
  title: "Truvern â€” Vendor Trust Network",
  description: "Verify once, share everywhere. Public trust profiles for vendors, faster vendor assessments for buyers.",
};
export default function RootLayout({ children }: { children: React.ReactNode }){
  return (
    <html lang="en">
      <body className="min-h-screen bg-white text-slate-900">
        <SessionWrap><I18nProvider>{children}</I18nProvider></SessionWrap>
      </body>
    </html>
  );
}
