# 🔍 findings.md — Research & Discoveries
> **Status:** 🟢 ACTIVE — Blueprint research complete
> **Last Updated:** 2026-10-20
> **Protocol:** B.L.A.S.T. v1.0

---

## 📡 Section 1: External Research

| Resource | Relevance | Notes |
|---|---|---|
| Supabase RBAC Multi-Tenant Pattern | ⭐⭐⭐ Critical | Use `SECURITY DEFINER` helper functions to avoid recursion in RLS |
| Next.js + Supabase Starter Boilerplate | ⭐⭐ Reference | Pattern for auth trigger to auto-create profile on sign-up |
| Supabase Storage Bucket Policies | ⭐⭐⭐ Critical | Separate bucket RLS needed for resumes & logos — not same as table RLS |
| point-source/supabase-tenant-rbac | ⭐⭐ Reference | Clean community RBAC seeder pattern |

---

## 🔌 Section 2: API & Integration Discoveries

| Service | Discovery | Impact |
|---|---|---|
| Supabase Auth | Roles must NOT live in `auth.users.raw_user_meta_data` — users can spoof these | 🔴 Critical — store roles in a secure `profiles` table instead |
| Supabase RLS | SQL Editor runs as `postgres` superuser, bypassing RLS — do NOT test policies in the editor | ⚠️ Important — test via client SDK or signed-in tokens |
| Supabase RLS | Unindexed FK columns in policies cause severe query degradation at scale | ⚠️ Add explicit indexes on `user_id`, `org_id`, `job_id` |
| Supabase Storage | Buckets have their own separate RLS policies — storage policies must mirror DB RBAC | 🔴 Critical — must implement storage policies for resume/logo buckets |
| Supabase REST `GET /rest/v1/` | Returns **HTTP 401** with anon key — root requires `service_role`. Use table-specific endpoints (e.g., `/rest/v1/profiles`) for anon-key queries. Auth ✅ and Storage ✅ endpoints work fine with anon key. | ⚠️ Update verify script to test a table endpoint, not the root |
| Python unavailable on host | `python` command not found — Microsoft Store alias only | 🔄 All tools rewritten in **Node.js** (v22.15.0 confirmed) |
| npm PowerShell policy | `npm.ps1` blocked by ExecutionPolicy — use `node` directly or `cmd` for npm | ⚠️ Use `node -e` for inline scripts; scaffold Vite via `cmd /c npm` |

---

## 🏗️ Section 3: Architecture Decisions

### Chosen Pattern: `SECURITY DEFINER` Helper Functions
**Why:** Using raw subqueries inside every RLS policy causes:
- Infinite recursion risk (profiles table querying itself)
- Performance degradation (N+1 policy evaluation)

**Solution:** Create reusable `SECURITY DEFINER` functions:
```sql
-- Returns all org IDs where current user is a member
CREATE OR REPLACE FUNCTION get_user_org_ids()
RETURNS SETOF UUID LANGUAGE SQL SECURITY DEFINER
SET search_path = '' STABLE AS $$
  SELECT org_id FROM public.organization_members WHERE user_id = auth.uid();
$$;

-- Checks if user is admin/recruiter for an org
CREATE OR REPLACE FUNCTION user_is_org_admin(target_org_id UUID)
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER
SET search_path = '' STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE org_id = target_org_id AND user_id = auth.uid()
    AND role IN ('owner', 'recruiter')
  );
$$;
```

### Auth Trigger Pattern
Auto-create a `profiles` row whenever a new user signs up in `auth.users`:
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role)
  VALUES (new.id, new.email, 'job_seeker');
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

### RLS Policy Blueprint (Confirmed)
| Table | Public SELECT | Auth INSERT | Owner UPDATE | Owner DELETE |
|---|---|---|---|---|
| `profiles` | ❌ Private | ✅ On signup trigger | ✅ Own row only | ❌ Admin only |
| `employer_profiles` | ✅ Public | ✅ Employer role | ✅ Own row only | ✅ Own row only |
| `job_listings` | ✅ Active only | ✅ Employer role | ✅ Own jobs only | ✅ Own jobs only |
| `applications` | ❌ Seeker own / Employer own-job only | ✅ Job Seeker role | ✅ Employer (status update) | ❌ Admin only |
| `saved_jobs` | ❌ Own only | ✅ Seeker role | — | ✅ Own only |

---

## ⚠️ Section 4: Constraints & Gotchas

1. **Role Spoofing Risk:** Never store roles in JWT metadata (`raw_user_meta_data`). Roles must live in a server-controlled `profiles` table with RLS.
2. **RLS SQL Editor Bypass:** Supabase SQL Editor runs as superuser and BYPASSES RLS. Always test security with the client SDK.
3. **Storage Bucket Policies:** Supabase Storage has its own separate policy system. A private bucket with no storage policy = completely locked (even to authenticated users). Must define bucket policies explicitly.
4. **Anon Key Safety:** The `anon` key is safe to expose in frontend JS. The `service_role` key must NEVER appear in any frontend code.
5. **Deduplication at DB Level:** Unique constraints on `(employer_id, title, location)` for job listings and `(job_id, seeker_id)` for applications. Do not rely on app-level validation alone.
6. **Index FK columns:** `user_id`, `org_id`, `job_id` in junction tables must be indexed — RLS adds implicit WHERE clauses that will table-scan without them.

---

## 🧠 Section 5: Self-Annealing Log

| Date | Error | Root Cause | Fix Applied | Architecture Updated? |
|---|---|---|---|---|
| 2026-10-20 | `GET /rest/v1/` → HTTP 401 with anon key | Supabase REST root requires `service_role`; anon key only works on table endpoints | Changed verify script to use Auth/Storage health endpoints + direct DB via MCP | ✅ Logged in findings.md |
| 2026-10-20 | `python` command not found | Python not installed; Windows Store alias present | Rewrote tools as Node.js scripts (v22.15.0 available) | ✅ tools/ will use `.js` going forward |
| 2026-10-20 | `npm.ps1` PowerShell ExecutionPolicy blocked | System script policy prevents running npm.ps1 | Use `cmd /c npm` or `node` directly | ✅ Logged |

---

## 💡 Section 6: Key Decisions

| Decision | Alternatives Considered | Rationale |
|---|---|---|
| Vanilla HTML/CSS/JS (or Vite) | Next.js, Nuxt | User spec says no framework unless explicitly requested. MVP with Vite for module support. |
| Roles in `profiles` table | `raw_user_meta_data` JWT claims | JWT metadata can be spoofed by users. DB-level roles with RLS are tamper-proof. |
| `SECURITY DEFINER` helper functions | Inline subqueries in every policy | Prevents recursion, improves RLS query performance significantly. |
| Unique DB constraints for deduplication | App-level validation | DB constraints are the last line of defense — cannot be bypassed by bad clients. |
