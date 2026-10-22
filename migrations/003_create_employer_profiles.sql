-- ============================================================
-- Migration 003: Create employer_profiles table
-- ============================================================
-- One row per employer user. user_id is UNIQUE (one profile per user).

CREATE TABLE IF NOT EXISTS public.employer_profiles (
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

-- Index: used by RLS policies and JOIN queries
CREATE INDEX IF NOT EXISTS idx_employer_profiles_user_id
  ON public.employer_profiles(user_id);

-- Enable RLS
ALTER TABLE public.employer_profiles ENABLE ROW LEVEL SECURITY;

-- updated_at trigger
CREATE TRIGGER trg_employer_profiles_updated_at
  BEFORE UPDATE ON public.employer_profiles
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
