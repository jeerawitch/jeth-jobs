# 📝 Applications Flow SOP — JobBoard Platform
> **Status:** 🟢 ACTIVE
> **Last Updated:** 2026-10-22
> **Depends on:** `02_database.md`, `03_job_listings.md`, `01_auth.md`

---

## 🎯 Purpose

Define the complete application submission, tracking, and management flow for both job seekers and employers.

---

## 📋 Operations Matrix

| Operation | Who | Condition |
|---|---|---|
| Submit application | Job Seeker | `is_job_seeker()` + job is `active` + not already applied |
| View own applications | Job Seeker | `seeker_id` matches own profile |
| View applicants for own job | Employer | `employer_id` matches job's employer |
| Update application status | Employer | Owns the job the application is for |
| Delete application | Admin only | `is_admin()` |
| Save a job | Job Seeker | `is_job_seeker()` |
| Remove saved job | Job Seeker | Owns the saved_job row |

---

## 🔄 Application Submission Flow

```
Seeker clicks "Apply" on a job listing
        ↓
Check: is user authenticated? → no: redirect to login
        ↓
Check: does user have a job_seeker_profile? → no: redirect to profile setup
        ↓
Check: has user already applied? (client-side pre-check)
        ↓
Show application form (cover letter, resume option: use profile's or upload new)
        ↓
If uploading new resume → upload to Supabase Storage 'resumes' bucket
        ↓
supabase.from('applications').insert({...})
        ↓
RLS: is_job_seeker() check
DB: UNIQUE (job_id, seeker_id) → 409 if duplicate
        ↓
Show success state — "Application submitted!"
```

---

## 🖥️ Frontend Implementation Patterns

### Check if Already Applied
```javascript
const { data: existing } = await supabase
  .from('applications')
  .select('id')
  .eq('job_id', jobId)
  .eq('seeker_id', seekerProfileId)
  .maybeSingle()

if (existing) { showAlreadyAppliedState() }
```

### Submit Application
```javascript
// Get seeker's profile id
const { data: seekerProfile } = await supabase
  .from('job_seeker_profiles')
  .select('id, resume_url')
  .single()

let resumeUrl = seekerProfile.resume_url  // use profile resume by default

// If user uploads a new resume
if (newResumeFile) {
  const filePath = `${auth.uid()}/resume_${Date.now()}.pdf`
  const { data: upload, error: uploadError } = await supabase.storage
    .from('resumes')
    .upload(filePath, newResumeFile, { upsert: true })

  if (!uploadError) {
    const { data: { publicUrl } } = supabase.storage
      .from('resumes')
      .getPublicUrl(filePath)
    resumeUrl = publicUrl
  }
}

const { data, error } = await supabase
  .from('applications')
  .insert({
    job_id:       jobId,
    seeker_id:    seekerProfile.id,
    cover_letter: formData.cover_letter || null,
    resume_url:   resumeUrl,
    status:       'pending'
  })
  .select()
  .single()

if (error?.code === '23505') {
  showError('You have already applied for this position.')
}
```

### Job Seeker: View My Applications
```javascript
const { data: applications } = await supabase
  .from('applications')
  .select(`
    id, status, created_at, cover_letter,
    job_listings (
      id, title, location, job_type, status,
      employer_profiles (company_name, company_logo_url)
    )
  `)
  .order('created_at', { ascending: false })
```

### Employer: View Applicants for a Job
```javascript
const { data: applicants } = await supabase
  .from('applications')
  .select(`
    id, status, created_at, cover_letter, resume_url,
    job_seeker_profiles (full_name, location, skills, bio)
  `)
  .eq('job_id', jobId)
  .order('created_at', { ascending: false })
// RLS ensures only the employer who owns the job can see this
```

### Employer: Update Application Status
```javascript
const { error } = await supabase
  .from('applications')
  .update({
    status:     newStatus,  // 'reviewing' | 'accepted' | 'rejected'
    updated_at: new Date().toISOString()
  })
  .eq('id', applicationId)
// RLS: employer must own the job this application belongs to
```

---

## 🔖 Saved Jobs (Bookmarks)

### Save a Job
```javascript
const { data: seekerProfile } = await supabase
  .from('job_seeker_profiles').select('id').single()

const { error } = await supabase
  .from('saved_jobs')
  .insert({ seeker_id: seekerProfile.id, job_id: jobId })

if (error?.code === '23505') { /* already saved — toggle off */ }
```

### Remove Saved Job
```javascript
const { error } = await supabase
  .from('saved_jobs')
  .delete()
  .match({ seeker_id: seekerProfileId, job_id: jobId })
```

### List Saved Jobs
```javascript
const { data: saved } = await supabase
  .from('saved_jobs')
  .select(`
    id, saved_at,
    job_listings (
      id, title, location, job_type, status,
      employer_profiles (company_name, company_logo_url)
    )
  `)
  .order('saved_at', { ascending: false })
```

---

## ⚠️ Edge Cases

| Case | Handling |
|---|---|
| Apply to inactive/closed job | Validate job `status = 'active'` before showing Apply button |
| Duplicate application | DB 23505 → friendly message "You've already applied" |
| Missing seeker profile | Redirect to profile setup before allowing application |
| Resume file > 5MB | Client-side size check before Supabase Storage upload |
| Employer views own job's applicants | RLS policy joins through `employer_profiles` to verify ownership |
