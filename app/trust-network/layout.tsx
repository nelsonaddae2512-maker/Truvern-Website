import type { Metadata } from "next";

export const metadata: Metadata = {
  title: { default: "Trust Network", template: "%s | Truvern" },
  description: "Discover and share vendor trust insights on Truvern.",
  alternates: { canonical: "/trust-network" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function TrustNetworkLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
