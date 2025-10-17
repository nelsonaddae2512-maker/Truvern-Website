--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (6bc9ef8)
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_session_jwt; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_session_jwt WITH SCHEMA public;


--
-- Name: EXTENSION pg_session_jwt; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_session_jwt IS 'pg_session_jwt: manage authentication sessions using JWTs';


--
-- Name: neon_auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA neon_auth;


--
-- Name: pgrst; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgrst;


--
-- Name: EvidenceStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."EvidenceStatus" AS ENUM (
    'pending',
    'approved',
    'rejected'
);


--
-- Name: Plan; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Plan" AS ENUM (
    'free',
    'pro',
    'enterprise'
);


--
-- Name: TrustLevel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."TrustLevel" AS ENUM (
    'low',
    'medium',
    'high'
);


--
-- Name: pre_config(); Type: FUNCTION; Schema: pgrst; Owner: -
--

CREATE FUNCTION pgrst.pre_config() RETURNS void
    LANGUAGE sql
    AS $$
  SELECT
      set_config('pgrst.db_schemas', 'public', true)
    , set_config('pgrst.db_aggregates_enabled', 'true', true)
    , set_config('pgrst.db_anon_role', 'anonymous', true)
    , set_config('pgrst.jwt_role_claim_key', '."role"', true)
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users_sync; Type: TABLE; Schema: neon_auth; Owner: -
--

CREATE TABLE neon_auth.users_sync (
    raw_json jsonb NOT NULL,
    id text GENERATED ALWAYS AS ((raw_json ->> 'id'::text)) STORED NOT NULL,
    name text GENERATED ALWAYS AS ((raw_json ->> 'display_name'::text)) STORED,
    email text GENERATED ALWAYS AS ((raw_json ->> 'primary_email'::text)) STORED,
    created_at timestamp with time zone GENERATED ALWAYS AS (to_timestamp((trunc((((raw_json ->> 'signed_up_at_millis'::text))::bigint)::double precision) / (1000)::double precision))) STORED,
    updated_at timestamp with time zone,
    deleted_at timestamp with time zone
);


--
-- Name: Answer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Answer" (
    id text NOT NULL,
    "vendorId" text NOT NULL,
    frameworks text[] DEFAULT ARRAY[]::text[],
    criticality text,
    maturity integer,
    "evidenceStatus" public."EvidenceStatus",
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: Evidence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Evidence" (
    id text NOT NULL,
    "vendorId" text NOT NULL,
    status public."EvidenceStatus" DEFAULT 'pending'::public."EvidenceStatus" NOT NULL,
    url text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: Membership; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Membership" (
    id text NOT NULL,
    "userId" text NOT NULL,
    "organizationId" text NOT NULL,
    role text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: Organization; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Organization" (
    id text NOT NULL,
    name text NOT NULL,
    plan public."Plan" DEFAULT 'free'::public."Plan" NOT NULL,
    seats integer DEFAULT 3 NOT NULL,
    "currentPeriodEnd" timestamp(3) without time zone,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


--
-- Name: PendingInvite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PendingInvite" (
    id text NOT NULL,
    email text NOT NULL,
    token text NOT NULL,
    "organizationId" text,
    "expiresAt" timestamp(3) without time zone NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: Usage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Usage" (
    id text NOT NULL,
    "organizationId" text NOT NULL,
    event text NOT NULL,
    count integer DEFAULT 0 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: User; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."User" (
    id text NOT NULL,
    email text NOT NULL,
    name text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


--
-- Name: Vendor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Vendor" (
    id text NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    "organizationId" text NOT NULL,
    "ownerId" text,
    "trustScore" integer DEFAULT 0 NOT NULL,
    "trustLevel" public."TrustLevel" DEFAULT 'low'::public."TrustLevel" NOT NULL,
    "trustUpdatedAt" timestamp(3) without time zone,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


--
-- Data for Name: users_sync; Type: TABLE DATA; Schema: neon_auth; Owner: -
--

COPY neon_auth.users_sync (raw_json, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: Answer; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Answer" (id, "vendorId", frameworks, criticality, maturity, "evidenceStatus", "createdAt") FROM stdin;
\.


--
-- Data for Name: Evidence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Evidence" (id, "vendorId", status, url, "createdAt") FROM stdin;
\.


--
-- Data for Name: Membership; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Membership" (id, "userId", "organizationId", role, "createdAt") FROM stdin;
\.


--
-- Data for Name: Organization; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Organization" (id, name, plan, seats, "currentPeriodEnd", "createdAt", "updatedAt") FROM stdin;
cmgn361jz0000gh7bk24591w1	Demo Org	pro	10	\N	2025-10-12 02:29:30.335	2025-10-12 02:29:30.335
\.


--
-- Data for Name: PendingInvite; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."PendingInvite" (id, email, token, "organizationId", "expiresAt", "createdAt") FROM stdin;
\.


--
-- Data for Name: Usage; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Usage" (id, "organizationId", event, count, "createdAt") FROM stdin;
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."User" (id, email, name, "createdAt", "updatedAt") FROM stdin;
cmgn361v70001gh7bcxdao8ho	demo@demo.com	Demo User	2025-10-12 02:29:30.739	2025-10-12 02:29:30.739
\.


--
-- Data for Name: Vendor; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Vendor" (id, name, slug, "organizationId", "ownerId", "trustScore", "trustLevel", "trustUpdatedAt", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
f9f04835-40cc-4981-b811-98b66aaac095	c122206da01888e8901f7dd5d51e04f94e0deecf975728eddf0f3b2e4576a1f5	2025-10-13 07:48:49.817386+00	20251013024842_baseline		\N	2025-10-13 07:48:49.817386+00	0
\.


--
-- Name: users_sync users_sync_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: -
--

ALTER TABLE ONLY neon_auth.users_sync
    ADD CONSTRAINT users_sync_pkey PRIMARY KEY (id);


--
-- Name: Answer Answer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Answer"
    ADD CONSTRAINT "Answer_pkey" PRIMARY KEY (id);


--
-- Name: Evidence Evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Evidence"
    ADD CONSTRAINT "Evidence_pkey" PRIMARY KEY (id);


--
-- Name: Membership Membership_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Membership"
    ADD CONSTRAINT "Membership_pkey" PRIMARY KEY (id);


--
-- Name: Organization Organization_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Organization"
    ADD CONSTRAINT "Organization_pkey" PRIMARY KEY (id);


--
-- Name: PendingInvite PendingInvite_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PendingInvite"
    ADD CONSTRAINT "PendingInvite_pkey" PRIMARY KEY (id);


--
-- Name: Usage Usage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Usage"
    ADD CONSTRAINT "Usage_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: Vendor Vendor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Vendor"
    ADD CONSTRAINT "Vendor_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: users_sync_deleted_at_idx; Type: INDEX; Schema: neon_auth; Owner: -
--

CREATE INDEX users_sync_deleted_at_idx ON neon_auth.users_sync USING btree (deleted_at);


--
-- Name: Answer_vendorId_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "Answer_vendorId_idx" ON public."Answer" USING btree ("vendorId");


--
-- Name: Evidence_vendorId_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "Evidence_vendorId_idx" ON public."Evidence" USING btree ("vendorId");


--
-- Name: Membership_organizationId_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "Membership_organizationId_idx" ON public."Membership" USING btree ("organizationId");


--
-- Name: Membership_userId_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "Membership_userId_idx" ON public."Membership" USING btree ("userId");


--
-- Name: Organization_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "Organization_name_key" ON public."Organization" USING btree (name);


--
-- Name: PendingInvite_email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "PendingInvite_email_key" ON public."PendingInvite" USING btree (email);


--
-- Name: PendingInvite_token_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "PendingInvite_token_key" ON public."PendingInvite" USING btree (token);


--
-- Name: Usage_organizationId_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "Usage_organizationId_idx" ON public."Usage" USING btree ("organizationId");


--
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- Name: Vendor_organizationId_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "Vendor_organizationId_idx" ON public."Vendor" USING btree ("organizationId");


--
-- Name: Vendor_slug_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "Vendor_slug_key" ON public."Vendor" USING btree (slug);


--
-- Name: Answer Answer_vendorId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Answer"
    ADD CONSTRAINT "Answer_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES public."Vendor"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Evidence Evidence_vendorId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Evidence"
    ADD CONSTRAINT "Evidence_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES public."Vendor"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Membership Membership_organizationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Membership"
    ADD CONSTRAINT "Membership_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES public."Organization"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Membership Membership_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Membership"
    ADD CONSTRAINT "Membership_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: PendingInvite PendingInvite_organizationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PendingInvite"
    ADD CONSTRAINT "PendingInvite_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES public."Organization"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Usage Usage_organizationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Usage"
    ADD CONSTRAINT "Usage_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES public."Organization"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Vendor Vendor_organizationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Vendor"
    ADD CONSTRAINT "Vendor_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES public."Organization"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Vendor Vendor_ownerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Vendor"
    ADD CONSTRAINT "Vendor_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON SCHEMA public TO truvern_app;


--
-- Name: SCHEMA pgrst; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA pgrst TO authenticator;


--
-- Name: FUNCTION pre_config(); Type: ACL; Schema: pgrst; Owner: -
--

GRANT ALL ON FUNCTION pgrst.pre_config() TO authenticator;


--
-- Name: TABLE "Answer"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Answer" TO authenticated;
GRANT ALL ON TABLE public."Answer" TO truvern_app;


--
-- Name: TABLE "Evidence"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Evidence" TO authenticated;
GRANT ALL ON TABLE public."Evidence" TO truvern_app;


--
-- Name: TABLE "Membership"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Membership" TO authenticated;
GRANT ALL ON TABLE public."Membership" TO truvern_app;


--
-- Name: TABLE "Organization"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Organization" TO authenticated;
GRANT ALL ON TABLE public."Organization" TO truvern_app;


--
-- Name: TABLE "PendingInvite"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."PendingInvite" TO authenticated;
GRANT ALL ON TABLE public."PendingInvite" TO truvern_app;


--
-- Name: TABLE "Usage"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Usage" TO authenticated;
GRANT ALL ON TABLE public."Usage" TO truvern_app;


--
-- Name: TABLE "User"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."User" TO authenticated;
GRANT ALL ON TABLE public."User" TO truvern_app;


--
-- Name: TABLE "Vendor"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Vendor" TO authenticated;
GRANT ALL ON TABLE public."Vendor" TO truvern_app;


--
-- Name: TABLE _prisma_migrations; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public._prisma_migrations TO authenticated;
GRANT ALL ON TABLE public._prisma_migrations TO truvern_app;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public GRANT USAGE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public GRANT ALL ON SEQUENCES TO truvern_app;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON TABLES TO neon_superuser WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public GRANT ALL ON TABLES TO truvern_app;


--
-- PostgreSQL database dump complete
--

