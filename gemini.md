# 📜 gemini.md — Project Constitution
> **Status:** 🟢 ACTIVE — Blueprint Phase Complete. Awaiting user approval.
> **Last Updated:** 2026-10-20
> **System Pilot Protocol:** B.L.A.S.T. v1.0

---

## 🏛️ I. Project Identity

| Field | Value |
|---|---|
| **Project Name** | JobBoard — Modern Job Search Platform |
| **North Star Goal** | A responsive web platform where job seekers find & apply for jobs, and employers post listings & recruit candidates |
| **Primary Stack** | HTML / CSS / JavaScript (Vanilla or Vite) + Supabase |
| **Database** | Supabase PostgreSQL |
| **Auth** | Supabase Auth (email/password + role-based) |
| **Storage** | Supabase Storage (resumes, company logos) |
| **Environment** | Local dev → Supabase cloud (MVP) |

---

## 🗂️ II. Data Schema (The "Payload") ← LAW

> ⚠️ **DATA-FIRST RULE:** No tools are written until this section is approved.
> ✅ **STATUS: DEFINED — Awaiting user approval before coding begins.**

---

### 👤 Table: `users` (managed by Supabase Auth)
```json
{
  "id": "uuid (PK, from auth.users)",
  "email": "string (unique)",
  "role": "enum: 'admin' | 'employer' | 'job_seeker'",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

---

### 🏢 Table: `employer_profiles`
```json
{
  "id": "uuid (PK)",
  "user_id": "uuid (FK → users.id)",
  "company_name": "string (unique, not null)",
  "company_logo_url": "string | null (Supabase Storage URL)",
  "description": "text | null",
  "website": "string | null",
  "location": "string | null",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

---

### 👔 Table: `job_seeker_profiles`
```json
{
  "id": "uuid (PK)",
  "user_id": "uuid (FK → users.id)",
  "full_name": "string (not null)",
  "resume_url": "string | null (Supabase Storage URL)",
  "bio": "text | null",
  "skills": "string[] (array of tags)",
  "location": "string | null",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

---

### 💼 Table: `job_listings`
```json
{
  "id": "uuid (PK)",
  "employer_id": "uuid (FK → employer_profiles.id)",
  "title": "string (not null)",
  "description": "text (not null)",
  "requirements": "text | null",
  "location": "string (not null)",
  "salary_min": "integer | null",
  "salary_max": "integer | null",
  "job_type": "enum: 'full-time' | 'part-time' | 'contract' | 'remote' | 'internship'",
  "category": "string (e.g., 'Engineering', 'Design', 'Marketing')",
  "status": "enum: 'draft' | 'active' | 'closed'",
  "created_at": "timestamp",
  "expires_at": "timestamp | null"
}
```
> **Deduplication Rule:** Unique constraint on `(employer_id, title, location)` — prevents duplicate postings.

---

### 📝 Table: `applications`
```json
{
  "id": "uuid (PK)",
  "job_id": "uuid (FK → job_listings.id)",
  "seeker_id": "uuid (FK → job_seeker_profiles.id)",
  "cover_letter": "text | null",
  "resume_url": "string | null (override or from profile)",
  "status": "enum: 'pending' | 'reviewing' | 'accepted' | 'rejected'",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```
> **Deduplication Rule:** Unique constraint on `(job_id, seeker_id)` — one application per job per seeker.

---

### 🔖 Table: `saved_jobs` (Bookmarks)
```json
{
  "id": "uuid (PK)",
  "seeker_id": "uuid (FK → job_seeker_profiles.id)",
  "job_id": "uuid (FK → job_listings.id)",
  "saved_at": "timestamp"
}
```

---

## ⚙️ III. Integrations & Services

| Service | Purpose | Status | Key Location |
|---|---|---|---|
| Supabase | DB, Auth, Storage, RLS | 🟡 MCP Connected — Keys TBD | `.env` |

---

## 👥 IV. Role-Based Access Control (RBAC)

| Role | Can Do | Cannot Do |
|---|---|---|
| **Admin** | Full access — manage users, listings, applications | — |
| **Employer** | Create/edit/delete own job listings, view own applicants | Edit others' jobs, view other employers' applicants |
| **Job Seeker** | Browse jobs, apply, save jobs, manage own profile | Post jobs, view other seekers' profiles/applications |
| **Public** | Browse active job listings | Apply, post, or view any personal data |

---

## 📐 V. Architectural Invariants

> Rules that must NEVER be broken.

1. **Tools are atomic.** Each script does exactly ONE thing.
2. **No hardcoded secrets.** All credentials live in `.env`.
3. **`.tmp/` is ephemeral.** Never treat temp files as permanent outputs.
4. **SOPs precede code.** Architecture docs updated before any logic change.
5. **Payloads reach the cloud.** Project is incomplete until data is in Supabase.
6. **RLS is always ON.** Every table has Row Level Security policies. No exceptions.
7. **Never expose API keys.** All Supabase keys are loaded from `.env`, never hardcoded in frontend JS.

---

## 🛡️ VI. Behavioral Rules

- **Authentication:** Supabase Auth required for all write operations.
- **RLS:** Every table must have Supabase RLS policies enforced at the DB level.
- **Deduplication:** Unique constraints on job listings and applications at DB level.
- **Input Validation:** All form inputs validated on both client and server (DB constraints).
- **Data Privacy:** Resumes and personal data are never publicly exposed. Storage buckets are private.
- **API Key Safety:** Supabase `anon` key used on frontend. `service_role` key NEVER in frontend code.
- **Employer Isolation:** Employers can only CRUD their own job listings. RLS enforces this.
- **Design:** Modern, responsive, user-friendly. Mobile-first. Premium aesthetics.

---

## 🔧 VII. Environment Variables

```env
# .env (DO NOT COMMIT)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
# SUPABASE_SERVICE_ROLE_KEY=  ← BACKEND/MIGRATION ONLY. Never in frontend.
```

---

## 🗺️ VIII. Architecture Overview

```
├── gemini.md               # Project Law (this file)
├── .env                    # API Keys/Secrets
├── architecture/
│   ├── 00_overview.md      # System architecture overview
│   ├── 01_auth.md          # Auth & RBAC SOP
│   ├── 02_database.md      # Schema, RLS policies SOP
│   ├── 03_job_listings.md  # Job listing CRUD SOP
│   ├── 04_applications.md  # Application flow SOP
│   └── 05_frontend.md      # UI/UX & routing SOP
├── tools/
│   ├── verify_supabase.py  # Phase 2: Link verification
│   ├── migrate_schema.py   # Apply DB migrations
│   └── seed_data.py        # Seed test data
├── .tmp/                   # Ephemeral workspace
└── src/                    # Frontend source (HTML/CSS/JS or Vite)
```

---

## 📋 IX. Maintenance Log

| Date | Change | Author |
|---|---|---|
| 2026-10-20 | Project Constitution initialized | System Pilot |
| 2026-10-20 | Discovery Q&A completed — full schema defined | System Pilot |
