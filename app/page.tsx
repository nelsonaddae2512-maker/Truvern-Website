import { Button } from "../components/ui/Button";

function LogosRow() {
  const names = ["Acme","Globex","Umbrella","Initech","Hooli","Stark"];
  return (
    <section className="mt-12 grid grid-cols-2 gap-3 sm:grid-cols-6">
      {names.map(n => (
        <div key={n} className="rounded-lg border bg-white py-3 text-center text-sm">{n}</div>
      ))}
    </section>
  );
}

function Features() {
  const items = [
    { title: "Trust Network", desc: "See real-world signals and share due diligence across your org." },
    { title: "Automated Assessments", desc: "Gather evidence, score controls, and export reports in minutes." },
    { title: "Continuous Monitoring", desc: "Track changes, alerts, and contract obligations over time." },
  ];
  return (
    <section className="mx-auto mt-20 grid max-w-6xl grid-cols-1 gap-6 px-6 sm:grid-cols-3">
      {items.map(i => (
        <div key={i.title} className="rounded-xl border bg-white p-6">
          <div className="text-lg font-semibold">{i.title}</div>
          <p className="mt-2 text-sm text-zinc-600">{i.desc}</p>
        </div>
      ))}
    </section>
  );
}

export default function Home() {
  return (
    <main className="mx-auto max-w-6xl px-6 py-16">
      <span className="inline-flex items-center rounded-full border px-3 py-1 text-sm text-zinc-600">Live on Vercel • Truvern</span>
      <h1 className="mt-6 text-5xl font-extrabold tracking-tight">Trust your vendors.</h1>
      <h2 className="text-4xl font-extrabold tracking-tight">Move faster with confidence.</h2>
      <p className="mt-4 max-w-2xl text-zinc-600">
        Truvern helps teams assess, compare, and continuously monitor third-party vendors.
      </p>
      <div className="mt-6 flex gap-3">
        <Button href="/assessment" className="bg-black text-white hover:bg-zinc-800">Get started</Button>
        <Button href="/compare" className="border hover:bg-zinc-50">Compare vendors</Button>
      </div>

      <LogosRow />
      <Features />

      <section className="mx-auto mt-20 max-w-3xl rounded-2xl border bg-white px-6 py-8 text-center">
        <h3 className="text-2xl font-bold">Ready to modernize third-party risk?</h3>
        <p className="mt-2 text-zinc-600">Start free. No credit card required.</p>
        <div className="mt-5 flex justify-center">
          <Button href="/assessment" className="bg-black text-white hover:bg-zinc-800">Start now</Button>
        </div>
      </section>
    </main>
  );
}
