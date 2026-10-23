# 🎨 Frontend UI/UX & Routing SOP — JobBoard Platform
> **Status:** 🟢 ACTIVE
> **Last Updated:** 2026-10-22
> **Depends on:** All other SOPs (frontend consumes the entire data layer)

---

## 🎯 Purpose

Define the frontend architecture, page structure, routing logic, and UI/UX guidelines.

---

## 🗺️ Page Map & Routes

| Route | Page | Auth Required | Role |
|---|---|---|---|
| `/` | Home / Job Browse | ❌ Public | Any |
| `/jobs/:id` | Job Detail | ❌ Public | Any |
| `/login` | Login / Register | ❌ Public (redirect if logged in) | — |
| `/dashboard` | Role-based redirect | ✅ Required | Any |
| `/dashboard/seeker` | Seeker Dashboard | ✅ Required | `job_seeker` |
| `/dashboard/seeker/applications` | My Applications | ✅ Required | `job_seeker` |
| `/dashboard/seeker/saved` | Saved Jobs | ✅ Required | `job_seeker` |
| `/dashboard/seeker/profile` | Seeker Profile Edit | ✅ Required | `job_seeker` |
| `/dashboard/employer` | Employer Dashboard | ✅ Required | `employer` |
| `/dashboard/employer/listings` | Manage Listings | ✅ Required | `employer` |
| `/dashboard/employer/listings/new` | Create Listing | ✅ Required | `employer` |
| `/dashboard/employer/listings/:id` | Edit Listing | ✅ Required | `employer` |
| `/dashboard/employer/applicants/:jobId` | View Applicants | ✅ Required | `employer` |
| `/dashboard/employer/profile` | Company Profile Edit | ✅ Required | `employer` |

---

## 🔄 Client-Side Routing

Using React Router v6 with lazy-loaded pages. The static host must rewrite all paths to `index.html` (SPA fallback); Vite's dev server already does this.

```jsx
// src/App.jsx
import { lazy, Suspense } from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'

const Home              = lazy(() => import('./pages/Home'))
const JobDetail         = lazy(() => import('./pages/JobDetail'))
const Login             = lazy(() => import('./pages/Login'))
const SeekerDashboard   = lazy(() => import('./pages/SeekerDashboard'))
const EmployerDashboard = lazy(() => import('./pages/EmployerDashboard'))
// ... etc

const router = createBrowserRouter([
  { path: '/',         element: <Home /> },
  { path: '/jobs/:id', element: <JobDetail /> },
  { path: '/login',    element: <Login /> },
  {
    path: '/dashboard/seeker',
    element: <ProtectedRoute role="job_seeker" />,
    children: [{ index: true, element: <SeekerDashboard /> } /* applications, saved, profile */],
  },
  {
    path: '/dashboard/employer',
    element: <ProtectedRoute role="employer" />,
    children: [{ index: true, element: <EmployerDashboard /> } /* listings, applicants, profile */],
  },
])

export default function App() {
  return (
    <AuthProvider>
      <Suspense fallback={null}>
        <RouterProvider router={router} />
      </Suspense>
    </AuthProvider>
  )
}
```

```jsx
// src/components/ProtectedRoute.jsx
import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function ProtectedRoute({ role }) {
  const { session, role: userRole, loading } = useAuth()

  if (loading) return null
  if (!session) return <Navigate to="/login" replace />
  if (role && userRole && userRole !== role) return <Navigate to="/dashboard" replace />
  return <Outlet />
}
```

`/dashboard` renders a small component that reads `role` from `useAuth()` and redirects to the matching dashboard. `ProtectedRoute` is UX only: RLS remains the real access control.

---

## 🎨 Design System

### Color Palette (CSS Custom Properties)
```css
:root {
  /* Brand */
  --color-primary:       hsl(221, 83%, 53%);   /* Blue */
  --color-primary-dark:  hsl(221, 83%, 40%);
  --color-primary-light: hsl(221, 83%, 95%);
  --color-accent:        hsl(262, 80%, 60%);   /* Purple accent */

  /* Neutrals */
  --color-bg:            hsl(220, 20%, 97%);
  --color-surface:       hsl(0, 0%, 100%);
  --color-border:        hsl(220, 15%, 90%);
  --color-text:          hsl(220, 25%, 15%);
  --color-text-muted:    hsl(220, 15%, 50%);

  /* Status */
  --color-success:       hsl(142, 71%, 45%);
  --color-warning:       hsl(38, 92%, 50%);
  --color-danger:        hsl(0, 84%, 60%);

  /* Typography */
  --font-sans:   'Inter', system-ui, sans-serif;
  --font-mono:   'JetBrains Mono', monospace;

  /* Spacing */
  --space-1: 4px;   --space-2: 8px;   --space-3: 12px;
  --space-4: 16px;  --space-6: 24px;  --space-8: 32px;
  --space-12: 48px; --space-16: 64px;

  /* Radii */
  --radius-sm: 6px;  --radius-md: 12px;  --radius-lg: 20px;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 3px rgba(0,0,0,.08);
  --shadow-md: 0 4px 16px rgba(0,0,0,.10);
  --shadow-lg: 0 8px 32px rgba(0,0,0,.12);
}
```

### Typography Scale
```css
h1 { font-size: 2.5rem;  font-weight: 700; }
h2 { font-size: 1.875rem; font-weight: 600; }
h3 { font-size: 1.375rem; font-weight: 600; }
h4 { font-size: 1.125rem; font-weight: 500; }
p  { font-size: 1rem;     line-height: 1.6; }
```

---

## 📐 Layout Components

Each block below is a React component in `src/components/`.

### Navigation Bar (`Navbar.jsx`)
- Logo + brand name (left)
- Search bar (center, home page only)
- Auth buttons or user menu (right)
- Sticky, glass-morphism effect on scroll

### Job Card (`JobCard.jsx`, Browse Grid)
```
┌────────────────────────────────────┐
│ 🏢 [Company Logo]  Company Name   │
│ 💼 Job Title                       │
│ 📍 Location  •  🕐 Job Type        │
│ 💰 Salary Range                    │
│ 🏷️ [Category Badge]               │
│                     [Apply →]      │
└────────────────────────────────────┘
```

### Dashboard Sidebar (`DashboardSidebar.jsx`)
- Profile avatar + name
- Navigation links (role-specific)
- Sign out button

---

## 🧩 Page Components Breakdown

### Home Page (`/`)
- Hero section with search bar (keyword + location filter)
- Filter bar (category chips, job type, salary range)
- Job listings grid (lazy-loaded, paginated)
- Stats bar (total jobs, companies, etc.)

### Job Detail (`/jobs/:id`)
- Full job description
- Company info card
- Apply button (or "Applied ✓" if already applied)
- Save/unsave toggle
- Related jobs sidebar

### Login/Register (`/login`)
- Tab: Sign In / Sign Up
- Sign Up: email + password → after submit, redirect to role selection
- Role selection: "I'm looking for a job" | "I'm hiring"

### Seeker Dashboard
- Stats: applications sent, saved jobs, profile views
- Recent applications table (with status badges)
- Quick-apply suggestions (based on saved category)

### Employer Dashboard
- Stats: active listings, total applicants, pending reviews
- Active listings table with quick-actions
- Recent applicants feed

---

## ⚠️ UX Rules

| Rule | Why |
|---|---|
| Show skeleton loaders, not spinners | Better perceived performance |
| Optimistic UI for save/unsave | Instant feedback, rollback on error |
| Truncate descriptions at 200 chars on cards | Clean browse experience |
| Mobile-first CSS | Most job seekers browse on mobile |
| Debounce search input (300ms) | Prevent excessive Supabase queries |
| Paginate job listings (20 per page) | Avoid loading thousands of rows |
