export const metadata = {
  title: "Truvern — Vendor Trust Network",
  description: "Verify once, share everywhere.",
};

export default function SiteLayout({ children }: { children: React.ReactNode }) {
  return (
    <main>
      {children}
    </main>
  );
}