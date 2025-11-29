import type { Metadata } from "next";

export const metadata: Metadata = {
  title: { default: "Board Reports", template: "%s | Truvern" },
  description: "Board-level risk dashboards and summaries powered by Truvern.",
  alternates: { canonical: "/reports/board" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function BoardReportsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
