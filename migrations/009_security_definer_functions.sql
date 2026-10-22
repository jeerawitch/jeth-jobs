-- ============================================================
-- Migration 009: SECURITY DEFINER Helper Functions
-- ============================================================
-- These functions are used inside RLS policies to avoid:
-- 1. Infinite recursion (profiles table querying itself)
-- 2. N+1 performance degradation in policy evaluation
--
-- SECURITY DEFINER: runs with the privileges of the function OWNER
-- (postgres superuser), not the calling user. This lets us safely
-- query profiles without triggering the profiles RLS policy itself.
--
-- SET search_path = '': prevents search_path injection attacks.
-- STABLE: function result is consistent within a single query.
-- ============================================================

-- ─────────────────────────────────────────
-- Role check helpers
-- ─────────────────────────────────────────

-- Get current user's role
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Returns TRUE if current user is a job_seeker
CREATE OR REPLACE FUNCTION public.is_job_seeker()
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'job_seeker'
  );
$$;

-- Returns TRUE if current user is an employer
CREATE OR REPLACE FUNCTION public.is_employer()
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'employer'
  );
$$;

-- Returns TRUE if current user is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- ─────────────────────────────────────────
-- Grant EXECUTE to authenticated users
-- ─────────────────────────────────────────
-- Supabase authenticated role must be able to call these from RLS policies.

GRANT EXECUTE ON FUNCTION public.get_my_role()    TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_job_seeker()  TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_employer()    TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin()       TO authenticated;
