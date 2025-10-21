export default function NotFound() {
  return (
    <main className="min-h-[60vh] grid place-items-center p-8 text-center">
      <div>
        <h1 className="text-4xl font-bold">404</h1>
        <p className="mt-2 text-gray-600">We couldn’t find that page.</p>
        <a className="mt-6 inline-block rounded-lg border px-4 py-2 hover:bg-gray-50" href="/">Back home</a>
      </div>
    </main>
  );
}
