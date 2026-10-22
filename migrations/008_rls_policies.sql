-- ============================================================
-- Migration 008: RLS Policies (all tables)
-- ============================================================
-- IMPORTANT: Run AFTER 009_security_definer_functions.sql
-- These policies use is_employer(), is_job_seeker(), is_admin()
-- helper functions defined in migration 009.
--
-- NOTE: Run migration 009 first, then this file, OR
-- apply them in order 009 → 008 if your runner executes alphabetically.
-- The migrate_schema.js runner applies them in filename order (001..010).
-- ============================================================

-- ─────────────────────────────────────────
-- TABLE: profiles
-- ─────────────────────────────────────────

-- Users can only read their own profile
CREATE POLICY "profiles: select own"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

-- Users can update their own profile
CREATE POLICY "profiles: update own"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

-- Only admins can delete profiles (protect against accidental deletion)
CREATE POLICY "profiles: delete admin only"
  ON public.profiles FOR DELETE
  USING (public.is_admin());

-- No direct INSERT — handled exclusively by auth trigger
-- (If needed for seeding, use service_role key)


-- ─────────────────────────────────────────
-- TABLE: employer_profiles
-- ─────────────────────────────────────────

-- Public: anyone can browse company profiles (for job cards)
CREATE POLICY "employer_profiles: public select"
  ON public.employer_profiles FOR SELECT
  USING (true);

-- Only employers can create their profile
CREATE POLICY "employer_profiles: employer insert"
  ON public.employer_profiles FOR INSERT
  WITH CHECK (public.is_employer() AND user_id = auth.uid());

-- Employers can only update their own profile
CREATE POLICY "employer_profiles: owner update"
  ON public.employer_profiles FOR UPDATE
  USING (user_id = auth.uid());

-- Employers can only delete their own profile
CREATE POLICY "employer_profiles: owner delete"
  ON public.employer_profiles FOR DELETE
  USING (user_id = auth.uid());


-- ─────────────────────────────────────────
-- TABLE: job_seeker_profiles
-- ─────────────────────────────────────────

-- Seekers can only read their own profile (private)
CREATE POLICY "job_seeker_profiles: select own"
  ON public.job_seeker_profiles FOR SELECT
  USING (user_id = auth.uid());

-- Only job seekers can create their profile
CREATE POLICY "job_seeker_profiles: seeker insert"
  ON public.job_seeker_profiles FOR INSERT
  WITH CHECK (public.is_job_seeker() AND user_id = auth.uid());

-- Seekers can update their own profile
CREATE POLICY "job_seeker_profiles: owner update"
  ON public.job_seeker_profiles FOR UPDATE
  USING (user_id = auth.uid());

-- Seekers can delete their own profile
CREATE POLICY "job_seeker_profiles: owner delete"
  ON public.job_seeker_profiles FOR DELETE
  USING (user_id = auth.uid());


-- ─────────────────────────────────────────
-- TABLE: job_listings
-- ─────────────────────────────────────────

-- Public can browse active listings (no auth needed)
CREATE POLICY "job_listings: public select active"
  ON public.job_listings FOR SELECT
  USING (
    status = 'active'
    AND (expires_at IS NULL OR expires_at > NOW())
  );

-- Employer can see ALL their own listings (including draft/closed)
CREATE POLICY "job_listings: employer select own"
  ON public.job_listings FOR SELECT
  USING (
    employer_id IN (
      SELECT id FROM public.employer_profiles WHERE user_id = auth.uid()
    )
  );

-- Only employers can create listings
CREATE POLICY "job_listings: employer insert"
  ON public.job_listings FOR INSERT
  WITH CHECK (
    public.is_employer()
    AND employer_id IN (
      SELECT id FROM public.employer_profiles WHERE user_id = auth.uid()
    )
  );

-- Employers can only update their own listings
CREATE POLICY "job_listings: owner update"
  ON public.job_listings FOR UPDATE
  USING (
    employer_id IN (
      SELECT id FROM public.employer_profiles WHERE user_id = auth.uid()
    )
  );

-- Employers can only delete their own listings
CREATE POLICY "job_listings: owner delete"
  ON public.job_listings FOR DELETE
  USING (
    employer_id IN (
      SELECT id FROM public.employer_profiles WHERE user_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────
-- TABLE: applications
-- ─────────────────────────────────────────

-- Seekers can see their own applications
CREATE POLICY "applications: seeker select own"
  ON public.applications FOR SELECT
  USING (
    seeker_id IN (
      SELECT id FROM public.job_seeker_profiles WHERE user_id = auth.uid()
    )
  );

-- Employers can see applications for their own jobs
CREATE POLICY "applications: employer select own job"
  ON public.applications FOR SELECT
  USING (
    job_id IN (
      SELECT jl.id FROM public.job_listings jl
      JOIN public.employer_profiles ep ON ep.id = jl.employer_id
      WHERE ep.user_id = auth.uid()
    )
  );

-- Only job seekers can submit applications
CREATE POLICY "applications: seeker insert"
  ON public.applications FOR INSERT
  WITH CHECK (
    public.is_job_seeker()
    AND seeker_id IN (
      SELECT id FROM public.job_seeker_profiles WHERE user_id = auth.uid()
    )
  );

-- Employers can update application status (for their own jobs only)
CREATE POLICY "applications: employer update status"
  ON public.applications FOR UPDATE
  USING (
    job_id IN (
      SELECT jl.id FROM public.job_listings jl
      JOIN public.employer_profiles ep ON ep.id = jl.employer_id
      WHERE ep.user_id = auth.uid()
    )
  );

-- Only admins can delete applications
CREATE POLICY "applications: admin delete"
  ON public.applications FOR DELETE
  USING (public.is_admin());


-- ─────────────────────────────────────────
-- TABLE: saved_jobs
-- ─────────────────────────────────────────

-- Seekers can only see their own saved jobs
CREATE POLICY "saved_jobs: seeker select own"
  ON public.saved_jobs FOR SELECT
  USING (
    seeker_id IN (
      SELECT id FROM public.job_seeker_profiles WHERE user_id = auth.uid()
    )
  );

-- Only job seekers can save jobs
CREATE POLICY "saved_jobs: seeker insert"
  ON public.saved_jobs FOR INSERT
  WITH CHECK (
    public.is_job_seeker()
    AND seeker_id IN (
      SELECT id FROM public.job_seeker_profiles WHERE user_id = auth.uid()
    )
  );

-- Seekers can unsave (delete) their own saved jobs
CREATE POLICY "saved_jobs: seeker delete own"
  ON public.saved_jobs FOR DELETE
  USING (
    seeker_id IN (
      SELECT id FROM public.job_seeker_profiles WHERE user_id = auth.uid()
    )
  );
