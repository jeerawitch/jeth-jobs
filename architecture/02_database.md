# 🗄️ Database Schema & RLS SOP — JobBoard Platform
> **Status:** 🟢 ACTIVE
> **Last Updated:** 2026-10-22
> **Depends on:** `01_auth.md` (SECURITY DEFINER functions must exist first)

---

## 🎯 Purpose

Define the complete database schema, migration order, indexes, and RLS policies for every table.

---

## 📋 Migration Execution Order

> ⚠️ Order matters — FK dependencies flow downward.

```
001_create_extensions.sql        ← uuid-ossp, pgcrypto
002_create_profiles.sql          ← auth trigger + profiles table
003_create_employer_profiles.sql ← depends on profiles
004_create_job_seeker_profiles.sql ← depends on profiles
005_create_job_listings.sql      ← depends on employer_profiles
006_create_applications.sql      ← depends on job_listings + job_seeker_profiles
007_create_saved_jobs.sql        ← depends on job_listings + job_seeker_profiles
008_rls_policies.sql             ← all tables must exist first
009_security_definer_functions.sql ← helper functions for RLS
010_storage_buckets.sql          ← Supabase Storage bucket creation
```

---

## 🗃️ Table Definitions

### `profiles` (mirrors `auth.users`)

```sql
CREATE TABLE public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL UNIQUE,
  role       TEXT NOT NULL DEFAULT 'job_seeker'
               CHECK (role IN ('admin', 'employer', 'job_seeker')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for RLS helper function lookups
CREATE INDEX idx_profiles_id ON public.profiles(id);
```

### `employer_profiles`

```sql
CREATE TABLE public.employer_profiles (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  company_name     TEXT NOT NULL UNIQUE,
  company_logo_url TEXT,
  description      TEXT,
  website          TEXT,
  location         TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_employer_profiles_user_id ON public.employer_profiles(user_id);
```

### `job_seeker_profiles`

```sql
CREATE TABLE public.job_seeker_profiles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  full_name  TEXT NOT NULL,
  resume_url TEXT,
  bio        TEXT,
  skills     TEXT[] DEFAULT '{}',
  location   TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_seeker_profiles_user_id ON public.job_seeker_profiles(user_id);
```

### `job_listings`

```sql
CREATE TABLE public.job_listings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id UUID NOT NULL REFERENCES public.employer_profiles(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  requirements TEXT,
  location    TEXT NOT NULL,
  salary_min  INTEGER CHECK (salary_min >= 0),
  salary_max  INTEGER CHECK (salary_max >= salary_min),
  job_type    TEXT NOT NULL
                CHECK (job_type IN ('full-time','part-time','contract','remote','internship')),
  category    TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft','active','closed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at  TIMESTAMPTZ,

  -- Deduplication: same employer cannot post same title+location twice
  CONSTRAINT uq_job_listings_employer_title_location
    UNIQUE (employer_id, title, location)
);

CREATE INDEX idx_job_listings_employer_id ON public.job_listings(employer_id);
CREATE INDEX idx_job_listings_status ON public.job_listings(status);
CREATE INDEX idx_job_listings_category ON public.job_listings(category);
```

### `applications`

```sql
CREATE TABLE public.applications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id       UUID NOT NULL REFERENCES public.job_listings(id) ON DELETE CASCADE,
  seeker_id    UUID NOT NULL REFERENCES public.job_seeker_profiles(id) ON DELETE CASCADE,
  cover_letter TEXT,
  resume_url   TEXT,
  status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','reviewing','accepted','rejected')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Deduplication: one application per job per seeker
  CONSTRAINT uq_applications_job_seeker
    UNIQUE (job_id, seeker_id)
);

CREATE INDEX idx_applications_job_id ON public.applications(job_id);
CREATE INDEX idx_applications_seeker_id ON public.applications(seeker_id);
```

### `saved_jobs`

```sql
CREATE TABLE public.saved_jobs (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seeker_id UUID NOT NULL REFERENCES public.job_seeker_profiles(id) ON DELETE CASCADE,
  job_id    UUID NOT NULL REFERENCES public.job_listings(id) ON DELETE CASCADE,
  saved_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_saved_jobs_seeker_job UNIQUE (seeker_id, job_id)
);

CREATE INDEX idx_saved_jobs_seeker_id ON public.saved_jobs(seeker_id);
CREATE INDEX idx_saved_jobs_job_id ON public.saved_jobs(job_id);
```

---

## 🛡️ RLS Policy Matrix

| Table | Policy | Role | Condition |
|---|---|---|---|
| `profiles` | SELECT | Owner | `id = auth.uid()` |
| `profiles` | INSERT | — | Via trigger only (no direct INSERT) |
| `profiles` | UPDATE | Owner | `id = auth.uid()` |
| `profiles` | DELETE | Admin | `is_admin()` |
| `employer_profiles` | SELECT | Public | All rows (public company info) |
| `employer_profiles` | INSERT | Employer | `is_employer()` |
| `employer_profiles` | UPDATE | Owner | `user_id = auth.uid()` |
| `employer_profiles` | DELETE | Owner | `user_id = auth.uid()` |
| `job_seeker_profiles` | SELECT | Owner | `user_id = auth.uid()` |
| `job_seeker_profiles` | INSERT | Job Seeker | `is_job_seeker()` |
| `job_seeker_profiles` | UPDATE | Owner | `user_id = auth.uid()` |
| `job_seeker_profiles` | DELETE | Owner | `user_id = auth.uid()` |
| `job_listings` | SELECT | Public | `status = 'active'` |
| `job_listings` | SELECT | Employer-owner | `employer_id IN (SELECT id FROM employer_profiles WHERE user_id = auth.uid())` |
| `job_listings` | INSERT | Employer | `is_employer()` |
| `job_listings` | UPDATE | Employer-owner | Same as select above |
| `job_listings` | DELETE | Employer-owner | Same as select above |
| `applications` | SELECT | Seeker-owner | `seeker_id IN (SELECT id FROM job_seeker_profiles WHERE user_id = auth.uid())` |
| `applications` | SELECT | Employer-owner | Job belongs to employer |
| `applications` | INSERT | Job Seeker | `is_job_seeker()` |
| `applications` | UPDATE | Employer (status only) | Employer owns the job |
| `applications` | DELETE | Admin | `is_admin()` |
| `saved_jobs` | SELECT | Seeker-owner | `seeker_id IN (SELECT id FROM job_seeker_profiles WHERE user_id = auth.uid())` |
| `saved_jobs` | INSERT | Job Seeker | `is_job_seeker()` |
| `saved_jobs` | DELETE | Seeker-owner | Same as select |

---

## ⚠️ Database Gotchas

1. **Test RLS with client SDK only.** SQL Editor runs as `postgres` superuser and bypasses all RLS.
2. **All FK columns have explicit indexes.** RLS policies add WHERE clauses on FK columns — without indexes, full table scans occur.
3. **`updated_at` must be refreshed manually** (or via a trigger) — Supabase does not auto-update it.
4. **`profiles.id` = `auth.users.id`** — they are the same UUID. Do NOT create a separate auto-increment PK.
