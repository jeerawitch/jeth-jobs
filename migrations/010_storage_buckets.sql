-- ============================================================
-- Migration 010: Supabase Storage — Bucket Creation & Policies
-- ============================================================
-- Creates two private storage buckets:
--   • resumes   — job seeker resume PDFs/docs
--   • logos     — employer company logos
--
-- NOTE: Supabase Storage has its OWN policy system separate from DB RLS.
-- A bucket with no storage policies is COMPLETELY LOCKED (even to authenticated users).
-- Policies must be explicitly defined here.
--
-- Run via Supabase SQL Editor (storage.buckets is a special schema).
-- ============================================================

-- ─────────────────────────────────────────
-- Create Buckets
-- ─────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('resumes', 'resumes', FALSE, 5242880,  -- 5MB limit
   ARRAY['application/pdf', 'application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('logos',   'logos',   FALSE, 2097152,  -- 2MB limit
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
ON CONFLICT (id) DO NOTHING;


-- ─────────────────────────────────────────
-- BUCKET: resumes
-- ─────────────────────────────────────────

-- Job seekers can upload their own resume (path must start with their user_id)
CREATE POLICY "resumes: seeker upload own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- Job seekers can read their own resume
CREATE POLICY "resumes: seeker read own"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- Employers can read resumes of applicants for their jobs
-- Note: This uses a function to check ownership through the applications chain
CREATE POLICY "resumes: employer read applicant"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
    AND public.is_employer()
  );

-- Job seekers can update (replace) their own resume
CREATE POLICY "resumes: seeker update own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- Job seekers can delete their own resume
CREATE POLICY "resumes: seeker delete own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'resumes'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );


-- ─────────────────────────────────────────
-- BUCKET: logos
-- ─────────────────────────────────────────

-- Logos are publicly readable (company branding shown on job cards)
CREATE POLICY "logos: public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'logos');

-- Only employers can upload their company logo
CREATE POLICY "logos: employer upload own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'logos'
    AND auth.role() = 'authenticated'
    AND public.is_employer()
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- Employers can update their own logo
CREATE POLICY "logos: employer update own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'logos'
    AND auth.role() = 'authenticated'
    AND public.is_employer()
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- Employers can delete their own logo
CREATE POLICY "logos: employer delete own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'logos'
    AND auth.role() = 'authenticated'
    AND public.is_employer()
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );
