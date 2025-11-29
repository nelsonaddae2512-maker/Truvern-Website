export default function Hero() {
  return (
    <section className="min-h-[80vh] flex flex-col items-center justify-center text-center bg-gradient-to-b from-blue-900/40 to-transparent">
      <h1 className="text-5xl md:text-6xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-cyan-300 mb-4">
        Build Trust. Simplify Risk.
      </h1>
      <p className="text-lg text-gray-300 max-w-xl mb-6">
        Truvern connects buyers and vendors through transparent, verified trust scores.
      </p>
      <a
        href="/trust-network"
        className="px-6 py-3 bg-blue-600 hover:bg-blue-500 rounded-lg font-medium text-white shadow-md transition-all"
      >
        Explore Network
      </a>
    </section>
  );
}
