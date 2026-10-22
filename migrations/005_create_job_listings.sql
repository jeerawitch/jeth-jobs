-- ============================================================
-- Migration 005: Create job_listings table
-- ============================================================
-- Core feature table. employer_id → employer_profiles (not profiles directly).

CREATE TABLE IF NOT EXISTS public.job_listings (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id  UUID NOT NULL REFERENCES public.employer_profiles(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT NOT NULL,
  requirements TEXT,
  location     TEXT NOT NULL,
  salary_min   INTEGER CHECK (salary_min IS NULL OR salary_min >= 0),
  salary_max   INTEGER CHECK (salary_max IS NULL OR salary_max >= 0),
  job_type     TEXT NOT NULL
                 CHECK (job_type IN ('full-time','part-time','contract','remote','internship')),
  category     TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft','active','closed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ,

  -- Deduplication: same employer cannot post same title + location twice
  CONSTRAINT uq_job_listings_employer_title_location
    UNIQUE (employer_id, title, location),

  -- salary range sanity check
  CONSTRAINT chk_salary_range
    CHECK (salary_max IS NULL OR salary_min IS NULL OR salary_max >= salary_min)
);

-- Indexes (critical for RLS + search performance)
CREATE INDEX IF NOT EXISTS idx_job_listings_employer_id ON public.job_listings(employer_id);
CREATE INDEX IF NOT EXISTS idx_job_listings_status      ON public.job_listings(status);
CREATE INDEX IF NOT EXISTS idx_job_listings_category    ON public.job_listings(category);
CREATE INDEX IF NOT EXISTS idx_job_listings_job_type    ON public.job_listings(job_type);
CREATE INDEX IF NOT EXISTS idx_job_listings_created_at  ON public.job_listings(created_at DESC);

-- Enable RLS
ALTER TABLE public.job_listings ENABLE ROW LEVEL SECURITY;
