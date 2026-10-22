-- ============================================================
-- Migration 004: Create job_seeker_profiles table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.job_seeker_profiles (
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

-- Index: used by RLS policies and JOIN queries
CREATE INDEX IF NOT EXISTS idx_job_seeker_profiles_user_id
  ON public.job_seeker_profiles(user_id);

-- Enable RLS
ALTER TABLE public.job_seeker_profiles ENABLE ROW LEVEL SECURITY;

-- updated_at trigger
CREATE TRIGGER trg_job_seeker_profiles_updated_at
  BEFORE UPDATE ON public.job_seeker_profiles
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
