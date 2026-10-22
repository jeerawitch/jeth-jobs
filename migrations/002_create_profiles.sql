-- ============================================================
-- Migration 002: Create profiles table + Auth Trigger
-- ============================================================
-- profiles mirrors auth.users (same UUID as PK).
-- Auto-populated via trigger on every new signup.
-- Roles are stored HERE — never in JWT raw_user_meta_data.

-- 1. Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL UNIQUE,
  role       TEXT NOT NULL DEFAULT 'job_seeker'
               CHECK (role IN ('admin', 'employer', 'job_seeker')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on id (used by SECURITY DEFINER helper functions)
CREATE INDEX IF NOT EXISTS idx_profiles_id ON public.profiles(id);

-- 2. Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. updated_at auto-refresh trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- 4. Auth trigger: auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role)
  VALUES (new.id, new.email, 'job_seeker');
  RETURN new;
END;
$$;

-- Drop if exists then recreate (idempotent)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
