export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="mt-10 py-10 text-center text-xs text-slate-500">
      <p>© {year} Truvern • TPRM Trust Network</p>

      <div className="mt-2 space-x-4">
        <a
          href="/legal/privacy"
          className="hover:text-sky-400 transition-colors"
        >
          Privacy
        </a>
        <a
          href="/security"
          className="hover:text-sky-400 transition-colors"
        >
          Security
        </a>
        <a
          href="/docs"
          className="hover:text-sky-400 transition-colors"
        >
          Docs
        </a>
      </div>
    </footer>
  );
}
