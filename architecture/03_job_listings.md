# 💼 Job Listings CRUD SOP — JobBoard Platform
> **Status:** 🟢 ACTIVE
> **Last Updated:** 2026-10-22
> **Depends on:** `02_database.md` (job_listings table + RLS), `01_auth.md` (employer role)

---

## 🎯 Purpose

Define the complete create/read/update/delete flow for job listings — the core feature of the platform.

---

## 📋 Operations Matrix

| Operation | Who | Condition | Notes |
|---|---|---|---|
| **Browse** (public) | Anyone | `status = 'active'` | No auth required |
| **Read own drafts** | Employer | Owns the listing | Auth required |
| **Create** | Employer | `is_employer()` | Must have employer_profile |
| **Edit** | Employer | Owns the listing | Partial updates allowed |
| **Publish / Close** | Employer | Owns the listing | Change `status` field |
| **Delete** | Employer | Owns the listing | Cascades to applications |
| **Admin CRUD** | Admin | Any listing | Full access |

---

## 🔄 Create Listing Flow

```
Employer fills out job form
        ↓
Client-side validation (required fields, salary_min ≤ salary_max)
        ↓
supabase.from('job_listings').insert({...})
        ↓
RLS: is_employer() check
        ↓
DB: employer_id auto-resolved from employer_profiles (user_id = auth.uid())
        ↓
DB UNIQUE constraint: (employer_id, title, location) → 409 if duplicate
        ↓
Row inserted with status = 'draft'
        ↓
Redirect employer to listing detail page
```

---

## 🖥️ Frontend Implementation Patterns

### Browse Active Jobs (Public)
```javascript
const { data: jobs, error } = await supabase
  .from('job_listings')
  .select(`
    id, title, location, job_type, category,
    salary_min, salary_max, created_at,
    employer_profiles (company_name, company_logo_url, location)
  `)
  .eq('status', 'active')
  .order('created_at', { ascending: false })
```

### Filter Jobs
```javascript
let query = supabase
  .from('job_listings')
  .select('*, employer_profiles(company_name)')
  .eq('status', 'active')

if (category)  query = query.eq('category', category)
if (jobType)   query = query.eq('job_type', jobType)
if (location)  query = query.ilike('location', `%${location}%`)
if (keyword)   query = query.or(`title.ilike.%${keyword}%,description.ilike.%${keyword}%`)

const { data, error } = await query.order('created_at', { ascending: false })
```

### Create a Listing (Employer)
```javascript
// First get employer_profile.id for the current user
const { data: empProfile } = await supabase
  .from('employer_profiles')
  .select('id')
  .single()

const { data, error } = await supabase
  .from('job_listings')
  .insert({
    employer_id:  empProfile.id,
    title:        formData.title,
    description:  formData.description,
    requirements: formData.requirements,
    location:     formData.location,
    salary_min:   parseInt(formData.salary_min) || null,
    salary_max:   parseInt(formData.salary_max) || null,
    job_type:     formData.job_type,
    category:     formData.category,
    status:       'draft',
    expires_at:   formData.expires_at || null
  })
  .select()
  .single()

if (error?.code === '23505') {
  // Unique constraint violation — duplicate listing
  showError('You already have a listing with this title and location.')
}
```

### Update Listing Status
```javascript
const { error } = await supabase
  .from('job_listings')
  .update({ status: 'active', updated_at: new Date().toISOString() })
  .eq('id', listingId)
// RLS ensures only the owner can update
```

### Delete Listing
```javascript
const { error } = await supabase
  .from('job_listings')
  .delete()
  .eq('id', listingId)
// Cascades: all applications for this job are also deleted
```

---

## 🏷️ Categories (Predefined List)
```javascript
export const JOB_CATEGORIES = [
  'Engineering', 'Design', 'Marketing', 'Sales',
  'Finance', 'HR', 'Operations', 'Customer Support',
  'Product', 'Data & Analytics', 'Legal', 'Other'
]

export const JOB_TYPES = [
  'full-time', 'part-time', 'contract', 'remote', 'internship'
]
```

---

## ⚠️ Edge Cases

| Case | Handling |
|---|---|
| Duplicate listing (same title + location) | DB 23505 → show user-friendly error |
| salary_min > salary_max | Client validation + DB CHECK constraint |
| Employer has no profile yet | Check employer_profiles first; redirect to setup |
| Deleting a job with applications | Cascade delete (by design) — warn employer before deletion |
| Expired listing still showing | Filter: `AND (expires_at IS NULL OR expires_at > NOW())` in public queries |
