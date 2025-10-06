
import React from "react";
import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";
export default function SiteLayout({ children }: { children: React.ReactNode }){
  return (
    <section>
      <SiteNav />
      <main>{children}</main>
      <SiteFooter />
    </section>
  );
}
