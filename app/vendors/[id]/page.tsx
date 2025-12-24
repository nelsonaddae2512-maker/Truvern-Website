// app/vendors/[id]/page.tsx
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import VendorRiskSnapshot from "@/components/vendors/vendor-risk-snapshot";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function safeStr(v: unknown) {
  return typeof v === "string" ? v.trim() : v == null ? "" : String(v).trim();
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function parseVendorId(raw: unknown): number | null {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const n = Number(s);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

export default async function VendorDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const org = await requireDbOrganization();
  const { id } = await params;
  const sp = (await searchParams) || {};
  const saved = typeof sp.saved === "string" ? sp.saved : "";
  const error = typeof sp.error === "string" ? sp.error : "";

  const vendorId = parseVendorId(id);
  if (!vendorId) return notFound();

  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId: org.id },
    select: {
      id: true,
      name: true,
      slug: true,
      category: true,
      summary: true,
      contactName: true,
      contactEmail: true,
      updatedAt: true,
      createdAt: true,
    },
  });

  if (!vendor) return notFound();

  async function updatePrimaryContact(formData: FormData) {
    "use server";

    const org = await requireDbOrganization();

    const vendorId = Number(safeStr(formData.get("vendorId")));
    if (!Number.isFinite(vendorId) || vendorId <= 0) redirect("/vendors");

    const contactName = safeStr(formData.get("contactName")) || null;
    const emailRaw = safeStr(formData.get("contactEmail"));
    const contactEmail = emailRaw ? emailRaw.toLowerCase() : null;

    if (contactEmail && !isValidEmail(contactEmail)) {
      redirect(`/vendors/${vendorId}?error=invalid_email`);
    }

    await prisma.vendor.updateMany({
      where: { id: vendorId, organizationId: org.id },
      data: { contactName, contactEmail } as any,
    });

    revalidatePath(`/vendors/${vendorId}`);
    revalidatePath("/vendors");
    revalidatePath("/evidence");
    redirect(`/vendors/${vendorId}?saved=contact`);
  }

  async function updateBasics(formData: FormData) {
    "use server";

    const org = await requireDbOrganization();

    const vendorId = Number(safeStr(formData.get("vendorId")));
    if (!Number.isFinite(vendorId) || vendorId <= 0) redirect("/vendors");

    const category = safeStr(formData.get("category")) || null;
    const summary = safeStr(formData.get("summary")) || null;

    await prisma.vendor.updateMany({
      where: { id: vendorId, organizationId: org.id },
      data: { category, summary } as any,
    });

    revalidatePath(`/vendors/${vendorId}`);
    revalidatePath("/vendors");
    redirect(`/vendors/${vendorId}?saved=basics`);
  }

  const hasEmail = !!(vendor.contactEmail && vendor.contactEmail.trim());

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold">{vendor.name}</h1>
          <p className="text-muted-foreground mt-1">
            Vendor details, risk snapshot, and primary contact used for reminders.
          </p>
        </div>
        <div className="flex gap-2">
          <Link className="btn-glass" href="/vendors">
            Back
          </Link>
          <Link className="btn-glass" href="/evidence">
            Evidence Inbox
          </Link>
        </div>
      </div>

      {error ? (
        <div className="mt-4 glass-soft rounded-xl border border-white/10 p-4 text-sm">
          <span className="text-amber-200">
            {error === "invalid_email"
              ? "Please enter a valid contact email."
              : "Please check and try again."}
          </span>
        </div>
      ) : null}

      {saved ? (
        <div className="mt-4 glass-soft rounded-xl border border-white/10 p-4 text-sm">
          <span className="text-emerald-200">
            {saved === "contact"
              ? "Primary contact saved."
              : saved === "basics"
              ? "Vendor basics saved."
              : "Saved."}
          </span>
        </div>
      ) : null}

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        {/* Left: Details */}
        <div className="lg:col-span-2 grid gap-6">
          {/* Basics */}
          <section className="glass-soft rounded-2xl border border-white/10 p-6">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-lg font-semibold">Basics</h2>
              <span className="text-xs text-muted-foreground">
                Updated {new Date(vendor.updatedAt).toLocaleDateString()}
              </span>
            </div>

            <form action={updateBasics} className="mt-4 grid gap-4">
              <input type="hidden" name="vendorId" value={vendor.id} />

              <div>
                <label className="block text-sm text-muted-foreground">Category</label>
                <input
                  name="category"
                  defaultValue={vendor.category ?? ""}
                  className="input-glass mt-2 w-full"
                  placeholder="e.g., Cloud / Identity / Payments"
                  autoComplete="off"
                />
              </div>

              <div>
                <label className="block text-sm text-muted-foreground">Summary</label>
                <textarea
                  name="summary"
                  defaultValue={vendor.summary ?? ""}
                  className="input-glass mt-2 w-full min-h-[120px]"
                  placeholder="Short vendor summary (optional)"
                />
              </div>

              <div className="flex justify-end">
                <button type="submit" className="btn-primary">
                  Save Basics
                </button>
              </div>
            </form>
          </section>

          {/* Primary Contact */}
          <section className="glass-soft rounded-2xl border border-white/10 p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-lg font-semibold">Primary Contact</h2>
                <p className="text-sm text-muted-foreground mt-1">
                  Evidence reminders will use this email.
                </p>
              </div>

              <span
                className={clsx(
                  "text-xs rounded-full px-2 py-1 border",
                  hasEmail
                    ? "border-emerald-400/30 text-emerald-200"
                    : "border-amber-400/30 text-amber-200"
                )}
              >
                {hasEmail ? "Email set" : "Missing email"}
              </span>
            </div>

            <form action={updatePrimaryContact} className="mt-4 grid gap-4 md:grid-cols-2">
              <input type="hidden" name="vendorId" value={vendor.id} />

              <div>
                <label className="block text-sm text-muted-foreground">Contact Name</label>
                <input
                  name="contactName"
                  defaultValue={vendor.contactName ?? ""}
                  className="input-glass mt-2 w-full"
                  placeholder="e.g., Security Team"
                  autoComplete="name"
                />
              </div>

              <div>
                <label className="block text-sm text-muted-foreground">Contact Email</label>
                <input
                  name="contactEmail"
                  type="email"
                  inputMode="email"
                  defaultValue={vendor.contactEmail ?? ""}
                  className="input-glass mt-2 w-full"
                  placeholder="e.g., security@vendor.com"
                  autoComplete="email"
                />
              </div>

              <div className="md:col-span-2 flex items-center justify-between gap-3">
                <div className="text-xs text-muted-foreground">
                  If email is missing, reminders are disabled in the Evidence Inbox.
                </div>
                <button type="submit" className="btn-primary">
                  Save Contact
                </button>
              </div>
            </form>
          </section>
        </div>

        {/* Right: Risk Snapshot */}
        <div className="grid gap-6">
          <section className="glass-soft rounded-2xl border border-white/10 p-6">
            <h2 className="text-lg font-semibold">Risk Snapshot</h2>
            <div className="mt-4">
              <VendorRiskSnapshot vendorId={vendor.id as any} />
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
