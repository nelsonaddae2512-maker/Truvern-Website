const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

function daysFromNow(n) {
  return new Date(Date.now() + n * 24 * 60 * 60 * 1000);
}

async function ensureIssueEvent(issueId, type, payload) {
  // Prevent duplicates by using a simple signature match
  const sig = JSON.stringify({ type, payload });
  const existing = await prisma.issueEvent.findFirst({
    where: { issueId, type, payload: payload ? payload : undefined },
    select: { id: true },
  });
  if (!existing) {
    await prisma.issueEvent.create({
      data: { issueId, type, payload },
    });
  }
}

async function main() {
  const email =
    process.env.SEED_USER_EMAIL ||
    process.env.CLERK_SEED_EMAIL ||
    "nelsonaddae@yahoo.com";

  // Org
  const org = await prisma.organization.upsert({
    where: { slug: "truvern-demo" },
    update: { name: "Truvern Demo Org" },
    create: { name: "Truvern Demo Org", slug: "truvern-demo" },
  });

  // User (email-based, stable)
  const user = await prisma.user.upsert({
    where: { email },
    update: { name: "Nelson Addae" },
    create: { email, name: "Nelson Addae" },
  });

  // Membership
  await prisma.orgMembership.upsert({
    where: {
      userId_organizationId: { userId: user.id, organizationId: org.id },
    },
    update: { role: "OWNER" },
    create: { userId: user.id, organizationId: org.id, role: "OWNER" },
  });

  // Primary org
  await prisma.user.update({
    where: { id: user.id },
    data: { organizationId: org.id },
  });

  // Vendors to seed
  const vendorsToSeed = [
    {
      name: "Acme Security",
      slug: "acme-security",
      category: "SaaS",
      tier: "CRITICAL",
      criticality: "HIGH",
      riskScore: 84,
      status: "Active",
      riskTrend30d: "DECLINING",
    },
    {
      name: "CloudLedger",
      slug: "cloudledger",
      category: "Finance",
      tier: "IMPORTANT",
      criticality: "MEDIUM",
      riskScore: 62,
      status: "Active",
      riskTrend30d: "STABLE",
    },
    {
      name: "DataForge Subprocessor",
      slug: "dataforge-subprocessor",
      category: "Sub-processor",
      tier: "CRITICAL",
      criticality: "HIGH",
      riskScore: 78,
      status: "Pending",
      riskTrend30d: "IMPROVING",
    },
    {
      name: "MailRunner",
      slug: "mailrunner",
      category: "Messaging",
      tier: "STANDARD",
      criticality: "LOW",
      riskScore: 41,
      status: "Active",
      riskTrend30d: "STABLE",
    },
    {
      name: "IdentityHub",
      slug: "identityhub",
      category: "Identity",
      tier: "IMPORTANT",
      criticality: "HIGH",
      riskScore: 71,
      status: "Active",
      riskTrend30d: "DECLINING",
    },
    {
      name: "LogLake",
      slug: "loglake",
      category: "Observability",
      tier: "STANDARD",
      criticality: "MEDIUM",
      riskScore: 55,
      status: "Active",
      riskTrend30d: "IMPROVING",
    },
  ];

  // Upsert vendors
  const vendors = {};
  for (const v of vendorsToSeed) {
    const vendor = await prisma.vendor.upsert({
      where: { slug: v.slug },
      update: {
        name: v.name,
        category: v.category,
        tier: v.tier,
        criticality: v.criticality,
        riskScore: v.riskScore,
        status: v.status,
        riskTrend30d: v.riskTrend30d,
        organizationId: org.id,
      },
      create: {
        name: v.name,
        slug: v.slug,
        category: v.category,
        tier: v.tier,
        criticality: v.criticality,
        riskScore: v.riskScore,
        status: v.status,
        riskTrend30d: v.riskTrend30d,
        organizationId: org.id,
      },
    });
    vendors[v.slug] = vendor;
  }

  // Issues to seed (findings inbox)
  const issuesToSeed = [
    {
      vendorSlug: "acme-security",
      title: "SOC 2 Type II report missing",
      description: "Vendor has not provided an up-to-date SOC 2 Type II report.",
      severity: "HIGH",
      status: "OPEN",
      dueAt: daysFromNow(14),
      events: [
        { type: "CREATED", payload: { note: "Seeded finding from assessment run." } },
        { type: "COMMENT", payload: { comment: "Requested evidence upload from vendor.", by: email } },
      ],
    },
    {
      vendorSlug: "acme-security",
      title: "MFA not enforced for admin accounts",
      description: "Admin console allows password-only access; requires MFA policy enforcement.",
      severity: "CRITICAL",
      status: "IN_REVIEW",
      dueAt: daysFromNow(7),
      events: [
        { type: "CREATED", payload: { source: "assessment", control: "IAM-02" } },
        { type: "STATUS_CHANGE", payload: { from: "OPEN", to: "IN_REVIEW" } },
      ],
    },
    {
      vendorSlug: "cloudledger",
      title: "Data retention policy not provided",
      description: "Need documented retention + deletion timeline for customer records.",
      severity: "MEDIUM",
      status: "OPEN",
      dueAt: daysFromNow(21),
      events: [{ type: "CREATED", payload: { source: "manual" } }],
    },
    {
      vendorSlug: "cloudledger",
      title: "Encryption at rest evidence incomplete",
      description: "Provided statement but no KMS / configuration evidence.",
      severity: "HIGH",
      status: "OPEN",
      dueAt: daysFromNow(10),
      events: [{ type: "CREATED", payload: { source: "assessment", control: "CRYPTO-01" } }],
    },
    {
      vendorSlug: "dataforge-subprocessor",
      title: "Subprocessor list missing",
      description: "Need complete list of subprocessors + countries + purposes.",
      severity: "HIGH",
      status: "OPEN",
      dueAt: daysFromNow(30),
      events: [{ type: "CREATED", payload: { source: "privacy-review" } }],
    },
    {
      vendorSlug: "mailrunner",
      title: "Incident response plan not shared",
      description: "Vendor has not provided IR plan or escalation contacts.",
      severity: "LOW",
      status: "OPEN",
      dueAt: daysFromNow(45),
      events: [{ type: "CREATED", payload: { source: "baseline" } }],
    },
    {
      vendorSlug: "identityhub",
      title: "SSO/SAML support unclear",
      description: "Enterprise SSO requirements not documented; confirm SAML/OIDC support.",
      severity: "MEDIUM",
      status: "OPEN",
      dueAt: daysFromNow(20),
      events: [{ type: "CREATED", payload: { source: "sales-ops" } }],
    },
    {
      vendorSlug: "identityhub",
      title: "Privileged access review overdue",
      description: "Quarterly privileged access review not completed.",
      severity: "HIGH",
      status: "RESOLVED",
      dueAt: daysFromNow(-5),
      events: [
        { type: "CREATED", payload: { source: "audit" } },
        { type: "STATUS_CHANGE", payload: { from: "OPEN", to: "RESOLVED" } },
      ],
    },
    {
      vendorSlug: "loglake",
      title: "Logging coverage gaps",
      description: "Critical auth events not included in central log stream.",
      severity: "MEDIUM",
      status: "IN_REVIEW",
      dueAt: daysFromNow(12),
      events: [
        { type: "CREATED", payload: { source: "assessment", control: "LOG-01" } },
        { type: "COMMENT", payload: { comment: "Vendor claims fix in next release.", by: "analyst@truvern.com" } },
      ],
    },
  ];

  let createdIssues = 0;

  for (const i of issuesToSeed) {
    const vendor = vendors[i.vendorSlug];
    if (!vendor) continue;

    // idempotency key: org + vendor + title
    const existing = await prisma.issue.findFirst({
      where: {
        organizationId: org.id,
        vendorId: vendor.id,
        title: i.title,
      },
      select: { id: true },
    });

    let issue;
    if (existing) {
      issue = await prisma.issue.update({
        where: { id: existing.id },
        data: {
          description: i.description,
          severity: i.severity,
          status: i.status,
          dueAt: i.dueAt,
          createdById: user.id,
          assignedToId: user.id,
        },
      });
    } else {
      issue = await prisma.issue.create({
        data: {
          title: i.title,
          description: i.description,
          severity: i.severity,
          status: i.status,
          organizationId: org.id,
          vendorId: vendor.id,
          dueAt: i.dueAt,
          createdById: user.id,
          assignedToId: user.id,
        },
      });
      createdIssues++;
    }

    // Seed timeline events (findings/audit trail)
    for (const ev of i.events || []) {
      await prisma.issueEvent.create({
        data: {
          issueId: issue.id,
          type: ev.type,
          payload: ev.payload,
        },
      });
    }
  }

  console.log("✅ Seed complete:", {
    email,
    orgId: org.id,
    userId: user.id,
    vendorCount: Object.keys(vendors).length,
    issuesAddedThisRun: createdIssues,
  });

  console.log("\nTry these URLs:");
  console.log("- http://localhost:3000/vendors");
  console.log("- http://localhost:3000/issues");
  console.log("- Click any issue row to validate /issues/[id]");
}

main()
  .catch((e) => {
    console.error("Seed failed (full error):");
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
