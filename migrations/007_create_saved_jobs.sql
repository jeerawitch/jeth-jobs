-- ============================================================
-- Migration 007: Create saved_jobs table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.saved_jobs (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seeker_id UUID NOT NULL REFERENCES public.job_seeker_profiles(id) ON DELETE CASCADE,
  job_id    UUID NOT NULL REFERENCES public.job_listings(id) ON DELETE CASCADE,
  saved_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Deduplication: seeker can save a job only once
  CONSTRAINT uq_saved_jobs_seeker_job UNIQUE (seeker_id, job_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_saved_jobs_seeker_id ON public.saved_jobs(seeker_id);
CREATE INDEX IF NOT EXISTS idx_saved_jobs_job_id    ON public.saved_jobs(job_id);

-- Enable RLS
ALTER TABLE public.saved_jobs ENABLE ROW LEVEL SECURITY;
