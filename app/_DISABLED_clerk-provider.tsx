export default function ClerkProviderShim({
  children,
}: {
  children: React.ReactNode;
}) {
  // IMPORTANT: Root app/layout.tsx is the only place we wrap ClerkProvider.
  return <>{children}</>;
}
