# 🔐 Auth & RBAC SOP — JobBoard Platform
> **Status:** 🟢 ACTIVE
> **Last Updated:** 2026-10-22
> **Depends on:** Supabase Auth (configured in `.env`)

---

## 🎯 Purpose

Define exactly how authentication and role-based access control (RBAC) work across the entire system. Every other SOP depends on this document.

---

## 👥 Roles

| Role | How Assigned | Description |
|---|---|---|
| `job_seeker` | **Default** — auto-assigned on signup via DB trigger | Browse & apply for jobs |
| `employer` | Manually set in `profiles.role` after signup | Post jobs, view applicants |
| `admin` | Manually set in `profiles.role` by another admin | Full system access |

> ⚠️ **CRITICAL:** Roles are stored ONLY in `public.profiles.role`. They are NEVER stored in `auth.users.raw_user_meta_data`. JWT claims can be spoofed by end users — DB table with RLS cannot.

---

## 🔄 Signup Flow

```
User submits email + password
        ↓
Supabase Auth creates row in auth.users
        ↓
DB Trigger: on_auth_user_created fires
        ↓
handle_new_user() inserts into public.profiles
with role = 'job_seeker' (default)
        ↓
User redirected to profile setup page
        ↓
Based on role selection at onboarding:
  - job_seeker → insert into job_seeker_profiles
  - employer   → insert into employer_profiles (+ admin sets role)
```

---

## 🛠️ Auth Trigger (SQL)

This trigger is defined in `migrations/002_create_profiles.sql`:

```sql
-- Function: auto-create profile on signup
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

-- Trigger: fires after INSERT on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

---

## 🔑 SECURITY DEFINER Helper Functions

These are the cornerstone of the RLS architecture. Instead of writing complex subqueries inside every RLS policy (which causes recursion and N+1 performance issues), we use reusable helper functions.

Defined in `migrations/009_security_definer_functions.sql`:

```sql
-- Get the current user's role from profiles table
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Check if current user is a job_seeker
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

-- Check if current user is an employer
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

-- Check if current user is an admin
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
```

---

## 🖥️ Frontend Auth Implementation

### Client Initialization (`src/lib/supabase.js`)

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

### Sign Up
```javascript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'secure-password'
})
// DB trigger auto-creates profiles row with role='job_seeker'
```

### Sign In
```javascript
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'secure-password'
})
```

### Sign Out
```javascript
const { error } = await supabase.auth.signOut()
```

### Get Session & Role
```javascript
const { data: { session } } = await supabase.auth.getSession()
if (!session) { /* redirect to login */ }

const { data: profile } = await supabase
  .from('profiles')
  .select('role')
  .single()

// Route based on role
if (profile.role === 'employer') { /* employer dashboard */ }
if (profile.role === 'job_seeker') { /* seeker dashboard */ }
```

### Auth State in React (`src/context/AuthContext.jsx`)

One app-wide listener lives in `AuthProvider`; components read session and role with `useAuth()`.

```jsx
import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null)
  const [role, setRole] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })
    return () => subscription.unsubscribe()
  }, [])

  // Role always comes from the profiles table, never from user_metadata
  useEffect(() => {
    if (!session) { setRole(null); return }
    supabase.from('profiles').select('role').single()
      .then(({ data }) => setRole(data?.role ?? null))
  }, [session])

  return (
    <AuthContext.Provider value={{ session, role, loading }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
```

---

## ⚠️ Gotchas & Rules

| Rule | Why |
|---|---|
| Never read role from JWT `user_metadata` | Users can write their own metadata — spoofable |
| Always check role from `profiles` table | Server-controlled, RLS-protected |
| Use `SECURITY DEFINER` functions in RLS | Prevents recursion when `profiles` policy references itself |
| Session is persisted in `localStorage` by default | Auto-refreshed by supabase-js |
| Test RLS with client SDK only | SQL Editor runs as superuser and BYPASSES RLS |
