# 🏛️ Architecture Overview — JobBoard Platform
> **Status:** 🟢 ACTIVE
> **Last Updated:** 2026-10-22
> **Protocol:** B.L.A.S.T. v1.0 — Phase 3: Architect

---

## 🎯 System Purpose

A responsive web platform where:
- **Job Seekers** discover and apply for jobs, manage their profile & resume
- **Employers** post job listings, review applicants, manage company profile
- **Admins** oversee all users, listings, and applications

---

## 🗺️ High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                   FRONTEND (Browser)                │
│   React + Vite (SPA, React Router)                  │
│                                                     │
│  ┌─────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Public │  │  Job Seeker  │  │   Employer    │  │
│  │  Pages  │  │  Dashboard   │  │   Dashboard   │  │
│  └────┬────┘  └──────┬───────┘  └───────┬───────┘  │
└───────┼──────────────┼──────────────────┼───────────┘
        │              │                  │
        ▼              ▼                  ▼
┌─────────────────────────────────────────────────────┐
│              Supabase JS SDK (anon key)             │
│         supabase-js v2 — loaded from .env           │
└──────┬────────────────┬────────────────┬────────────┘
       │                │                │
       ▼                ▼                ▼
┌────────────┐  ┌──────────────┐  ┌────────────────┐
│ Supabase   │  │  Supabase    │  │   Supabase     │
│    Auth    │  │  PostgreSQL  │  │   Storage      │
│            │  │  (RLS ON)    │  │ (Private Bkts) │
└────────────┘  └──────────────┘  └────────────────┘
```

---

## 📦 Technology Stack

| Layer | Technology | Notes |
|---|---|---|
| **Frontend** | React 18 + Vite | SPA, function components + hooks, React Router v6 |
| **Styling** | Plain CSS | CSS custom properties (design tokens), global `index.css` |
| **Auth** | Supabase Auth | Email/password, session persistence |
| **Database** | Supabase PostgreSQL 17 | RLS ON, SECURITY DEFINER helpers |
| **Storage** | Supabase Storage | Private buckets with bucket-level RLS |
| **Hosting** | Supabase (backend) + Static host (frontend) | MVP phase: local dev |

---

## 🗂️ Directory Structure

```
init-project/
├── gemini.md                    # Project Constitution (LAW)
├── task_plan.md                 # B.L.A.S.T. phase tracker
├── findings.md                  # Research & gotcha log
├── progress.md                  # Step-by-step progress
├── .env                         # Secrets (NOT committed)
├── .gitignore
│
├── architecture/                # SOPs (this folder)
│   ├── 00_overview.md           ← YOU ARE HERE
│   ├── 01_auth.md               # Auth & RBAC SOP
│   ├── 02_database.md           # Schema & RLS SOP
│   ├── 03_job_listings.md       # Job listing CRUD SOP
│   ├── 04_applications.md       # Application flow SOP
│   └── 05_frontend.md           # UI/UX & routing SOP
│
├── tools/
│   ├── verify_supabase.js       # Phase 2: connection verified ✅
│   └── migrate_schema.js        # Phase 3: apply DB migrations
│
├── migrations/
│   ├── 001_create_extensions.sql
│   ├── 002_create_profiles.sql
│   ├── 003_create_employer_profiles.sql
│   ├── 004_create_job_seeker_profiles.sql
│   ├── 005_create_job_listings.sql
│   ├── 006_create_applications.sql
│   ├── 007_create_saved_jobs.sql
│   ├── 008_rls_policies.sql
│   ├── 009_security_definer_functions.sql
│   └── 010_storage_buckets.sql
│
└── src/                         # Frontend (React + Vite scaffold — Phase 3 Layer 4)
    ├── main.jsx                 # React entry, mounts <App />
    ├── App.jsx                  # Router + AuthProvider
    ├── index.css                # Design tokens & global styles
    ├── lib/supabase.js          # Supabase client (anon key)
    ├── context/AuthContext.jsx  # Session + role, useAuth() hook
    ├── components/              # Navbar, JobCard, DashboardSidebar, ProtectedRoute
    └── pages/                   # One component per route
```

---

## 🔐 Security Architecture

### Defense-in-Depth (3 Layers)

```
Layer 1: Client Validation  →  JS form validation (UX, not security)
Layer 2: RLS Policies       →  PostgreSQL enforces per-row access
Layer 3: DB Constraints     →  Unique constraints, NOT NULL, FK integrity
```

### Key Security Rules
1. **Anon key** — safe to ship in frontend JS (read-only public data)
2. **Service role key** — NEVER in frontend; migration scripts only via `.env`
3. **Roles stored in `profiles` table** — never in JWT `raw_user_meta_data` (spoofable)
4. **RLS always ON** — no table may exist without a policy
5. **Storage buckets private by default** — explicit policies required

---

## 🧭 Request Flow Examples

### Public User Browses Jobs
```
Browser → supabase.from('job_listings').select() 
        → RLS: status = 'active' AND anon allowed 
        → Returns active listings only
```

### Job Seeker Applies
```
Browser (authenticated) → supabase.from('applications').insert(...)
        → RLS: role = 'job_seeker' AND not duplicate
        → DB unique constraint: (job_id, seeker_id)
        → Row inserted or 409 conflict
```

### Employer Views Applicants
```
Browser (authenticated) → supabase.from('applications').select(...)
        → RLS: employer owns the job_listing (via employer_profiles FK)
        → Returns only applicants for employer's own jobs
```

---

## 📋 SOP Reading Order

Build in this order (dependencies flow top → bottom):

1. [`01_auth.md`](./01_auth.md) — Auth first, everything depends on `auth.uid()`
2. [`02_database.md`](./02_database.md) — Schema + RLS (core data layer)
3. [`03_job_listings.md`](./03_job_listings.md) — First major feature
4. [`04_applications.md`](./04_applications.md) — Depends on job_listings + seeker profiles
5. [`05_frontend.md`](./05_frontend.md) — UI built on top of working DB
