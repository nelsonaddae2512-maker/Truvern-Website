// app/vendors/new/page.tsx
import Link from "next/link";
import { redirect } from "next/navigation";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function safeStr(v: unknown) {
  return typeof v === "string" ? v.trim() : v == null ? "" : String(v).trim();
}

function slugify(input: string) {
  const s = input
    .toLowerCase()
    .trim()
    .replace(/['"]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
  return s || "vendor";
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function ensureUniqueVendorSlug(orgId: number, baseName: string) {
  const base = slugify(baseName);
  let slug = base;
  for (let i = 0; i < 50; i++) {
    const exists = await prisma.vendor.findFirst({
      where: { organizationId: orgId, slug },
      select: { id: true },
    });
    if (!exists) return slug;
    slug = `${base}-${i + 2}`;
  }
  return `${base}-${Date.now()}`;
}

export default async function NewVendorPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireDbOrganization();
  const sp = (await searchParams) || {};
  const error = typeof sp.error === "string" ? sp.error : "";

  async function createVendor(formData: FormData) {
    "use server";

    const org = await requireDbOrganization();

    const name = safeStr(formData.get("name"));
    const category = safeStr(formData.get("category")) || null;
    const summary = safeStr(formData.get("summary")) || null;

    const contactName = safeStr(formData.get("contactName")) || null;
    const contactEmailRaw = safeStr(formData.get("contactEmail"));
    const contactEmail = contactEmailRaw ? contactEmailRaw.toLowerCase() : null;

    if (!name) redirect("/vendors/new?error=missing_name");
    if (contactEmail && !isValidEmail(contactEmail)) redirect("/vendors/new?error=invalid_email");

    const slug = await ensureUniqueVendorSlug(org.id, name);

    const created = await prisma.vendor.create({
      data: {
        organizationId: org.id,
        name,
        slug,
        category,
        summary,
        contactName,
        contactEmail,
      } as any,
      select: { id: true },
    });

    redirect(`/vendors/${created.id}`);
  }

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold">New Vendor</h1>
          <p className="text-muted-foreground mt-1">
            Create a vendor and optionally set a primary contact.
          </p>
        </div>
        <div className="flex gap-2">
          <Link className="btn-glass" href="/vendors">
            Back
          </Link>
        </div>
      </div>

      {error ? (
        <div className="mt-4 glass-soft rounded-xl border border-white/10 p-4 text-sm">
          <span className="text-amber-200">
            {error === "missing_name"
              ? "Vendor name is required."
              : error === "invalid_email"
              ? "Please enter a valid contact email."
              : "Please check the form and try again."}
          </span>
        </div>
      ) : null}

      <form action={createVendor} className="mt-6 glass-soft rounded-2xl border border-white/10 p-6">
        <div className="grid gap-6 md:grid-cols-2">
          {/* Basics */}
          <section className="rounded-2xl border border-white/10 p-5">
            <h2 className="text-lg font-semibold">Basics</h2>

            <label className="mt-4 block text-sm text-muted-foreground">Vendor Name</label>
            <input
              name="name"
              className="input-glass mt-2 w-full"
              placeholder="e.g., LogLake"
              autoComplete="organization"
              required
            />

            <label className="mt-4 block text-sm text-muted-foreground">Category</label>
            <input
              name="category"
              className="input-glass mt-2 w-full"
              placeholder="e.g., Cloud / Identity / Payments"
              autoComplete="off"
            />

            <label className="mt-4 block text-sm text-muted-foreground">Summary</label>
            <textarea
              name="summary"
              className="input-glass mt-2 w-full min-h-[96px]"
              placeholder="Short vendor summary (optional)"
            />
          </section>

          {/* Primary Contact */}
          <section className="rounded-2xl border border-white/10 p-5">
            <h2 className="text-lg font-semibold">Primary Contact</h2>
            <p className="text-sm text-muted-foreground mt-1">
              Used for evidence reminders and notifications.
            </p>

            <label className="mt-4 block text-sm text-muted-foreground">Contact Name</label>
            <input
              name="contactName"
              className="input-glass mt-2 w-full"
              placeholder="e.g., Security Team"
              autoComplete="name"
            />

            <label className="mt-4 block text-sm text-muted-foreground">Contact Email</label>
            <input
              name="contactEmail"
              type="email"
              inputMode="email"
              className="input-glass mt-2 w-full"
              placeholder="e.g., security@vendor.com"
              autoComplete="email"
            />

            <div className="mt-4 text-xs text-muted-foreground">
              Tip: If email is missing, the Evidence Inbox will show “Add email” and disable reminders.
            </div>
          </section>
        </div>

        <div className="mt-6 flex items-center justify-end gap-2">
          <Link className="btn-glass" href="/vendors">
            Cancel
          </Link>
          <button type="submit" className="btn-primary">
            Create Vendor
          </button>
        </div>
      </form>
    </main>
  );
}
