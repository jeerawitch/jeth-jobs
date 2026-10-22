-- ============================================================
-- Migration 006: Create applications table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.applications (
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
  CONSTRAINT uq_applications_job_seeker UNIQUE (job_id, seeker_id)
);

-- Indexes (critical for RLS — both FK columns appear in WHERE clauses)
CREATE INDEX IF NOT EXISTS idx_applications_job_id    ON public.applications(job_id);
CREATE INDEX IF NOT EXISTS idx_applications_seeker_id ON public.applications(seeker_id);
CREATE INDEX IF NOT EXISTS idx_applications_status    ON public.applications(status);

-- Enable RLS
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

-- updated_at trigger
CREATE TRIGGER trg_applications_updated_at
  BEFORE UPDATE ON public.applications
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
