export default function ClientProviders({
  children,
}: {
  children: React.ReactNode;
}) {
  // Root app/layout.tsx already wraps providers.
  return <>{children}</>;
}
