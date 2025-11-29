export default function NotFound() {
  return (
    <main className="container-page py-16">
      <h1 className="text-3xl font-semibold tracking-tight">Page not found</h1>
      <p className="mt-3 text-sm text-zinc-600 dark:text-zinc-400">
        The page you’re looking for doesn’t exist.
      </p>
      <a href="/" className="mt-6 inline-block underline">Go back home</a>
    </main>
  );
}