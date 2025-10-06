
# Truvern — Vendor Trust Network (Fullstack, ready for GitHub)

Domain: **https://truvern.com**

## What you get
- Marketing site (App Router) — landing, features, pricing, vendors, buyers, trust‑network, legal, contact
- Public Trust Directory & Trust Badge
- Email magic links (NextAuth + Resend) with domain allowlist + invite‑based onboarding
- Stripe subscriptions (checkout/portal/webhook)
- Usage & MRR dashboard
- Prisma/Postgres schema + seed
- TailwindCSS styling
- Dockerfile, CI, optional Vercel deploy workflow

## Local setup
```bash
git clone <YOUR_REPO_URL> truvern
cd truvern
cp .env.example .env.local
# Fill NEXTAUTH_SECRET, DATABASE_URL, RESEND_API_KEY (email), Stripe keys (optional for now)
npm i
npm run prisma:generate
npm run prisma:push
npm run seed
npm run dev
```

Open:
- `/` (landing)
- `/trust` (directory)
- `/trust/acme-labs` (demo vendor)
- `/login` (magic link login)
- `/subscribe` (plans)
- `/dashboard/billing` (usage & revenue)

## Push to GitHub (one‑time)
```bash
git init
git branch -M main
git remote add origin https://github.com/<you>/truvern.git
git add -A
git commit -m "Init Truvern vendor trust"
git push -u origin main
```

## Vercel deploy (recommended)
1. Import the GitHub repo into Vercel.
2. Add environment variables from `.env.example`:
   - `NEXTAUTH_URL=https://truvern.com`
   - `NEXTAUTH_SECRET=<32+ char secret>`
   - `DATABASE_URL=<managed Postgres>`
   - `RESEND_API_KEY`, `EMAIL_FROM=security@truvern.com`
   - (Stripe) `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, and `PRICE_*` IDs
3. Point DNS for **truvern.com** to Vercel (instructions in Vercel > Settings > Domains).
4. Redeploy.

## Invites & allowed domains
- Allow only company domains via `ALLOWED_EMAIL_DOMAINS`.
- Invite external users:
```bash
curl -XPOST https://truvern.com/api/invites/create -H 'content-type: application/json' -d '{"email":"partner@example.com","role":"MEMBER"}'
```
- Invitee opens `/invite/<token>` then `/login` to receive a magic link.
- On first login, they get assigned to your organization automatically.

## Production checklist
- Replace placeholder texts and add brand assets
- Configure Stripe products & prices, set webhook to `/api/stripe/webhook`
- Enable Upstash Redis for production rate limiting (optional)
- Add security headers (Next middleware or Vercel config)
- Review Privacy/Terms pages with counsel

— © Truvern


## New in this bundle
- **Branding:** logo component + polished pricing
- **Evidence upload:** `/vendor/upload` UI + `/api/evidence/upload` endpoint (URL-based)
- **SSO/SAML preview:** `/sso` page + `/api/sso/saml/metadata` (stub)
- **Badge embed page:** `/trust/embed` helper



## Phase 4 enhancements (added now)
- **S3 presigned file uploads**: `/vendor/upload-file` UI, `/api/evidence/presign` route (requires S3 env vars).
- **SAML SSO (preview)**: `/api/sso/saml/acs` handler with `samlify` (minimal validator), `/api/sso/logout`, `/sso` settings. Bring your IdP values via env.
- **i18n**: lightweight translation context (en/es/fr) with language selector (CTA); remembers via `localStorage`.
- **Geo-pricing**: currency auto-detect via `x-vercel-ip-country` with simple FX mapping (non-binding; display only).

### Configure S3 uploads
Set in env (Vercel Project → Settings → Environment Variables):
```
S3_REGION=us-east-1
S3_BUCKET=<your-bucket>
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```
Grant `PutObject` on the bucket.

### Configure SAML (Enterprise)
Provide:
```
SAML_SP_ENTITY_ID=https://truvern.com/sso/saml
SAML_ACS_URL=https://truvern.com/api/sso/saml/acs
SAML_IDP_ENTITY_ID=...
SAML_IDP_SSO_URL=...
SAML_IDP_CERT=-----BEGIN CERTIFICATE-----...-----END CERTIFICATE-----
SAML_EMAIL_ATTRIBUTE=urn:oid:0.9.2342.19200300.100.1.3
```
**Note:** The demo skips XSD validation. In production, add `@authenio/samlify-xsd-schema-validator` and wire to NextAuth session creation.



## Phase 5 upgrades (this bundle)
- **Full SAML → NextAuth** via Credentials provider handoff. Set `SAML_*` env and `SAML_SESSION_SECRET`. IdP agnostic (Okta/Entra/OneLogin).
- **S3 signed GET** downloads: `/api/evidence/get-url?key=...` (requires S3 env).
- **GA4 analytics**: set `NEXT_PUBLIC_GA_MEASUREMENT_ID` to enable pageview tracking globally.
- **Role-based dashboards**: `/dashboard` shows vendor & buyer workspaces.
- **Security**: basic security headers via middleware.

### How SAML login works
1) IdP posts assertion to `/api/sso/saml/acs`.
2) ACS extracts email and issues a short signed handoff token.
3) Redirect to NextAuth `credentials` callback, which validates the token and signs the user in.
4) User appears as authenticated in the app.



## Phase 6 upgrades
- **Full-site i18n** for nav/footer/CTA (EN/ES/FR/DE) + language switcher.
- **Evidence reviewer API** `/api/evidence/review` and demo page `/dashboard/review`.
- **SAML org mapping**: ACS auto-provisions an org by email domain and ensures membership.


### Reviewer queue
- List evidence pending/rejected for your orgs: `GET /api/evidence/list`
- Approve/reject with note: `POST /api/evidence/review`
- View private S3 assets via `GET /api/evidence/get-url?key=...`
- UI: `/dashboard/review`
