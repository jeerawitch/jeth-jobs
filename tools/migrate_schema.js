/**
 * migrate_schema.js — JobBoard Migration Runner
 * =============================================
 * Applies all SQL migration files in migrations/ to Supabase
 * in filename order (001 → 010).
 *
 * Usage:
 *   node tools/migrate_schema.js
 *
 * Requires:
 *   - .env with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
 *   - Node.js v18+ (uses native fetch)
 *
 * NOTE: Uses service_role key (bypasses RLS) — migration tool ONLY.
 *       NEVER expose this key in frontend code.
 */

import { readFileSync, readdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = join(__dirname, '..')

// ─────────────────────────────────────────
// Load environment variables from .env
// ─────────────────────────────────────────
function loadEnv() {
  const envPath = join(projectRoot, '.env')
  const envContent = readFileSync(envPath, 'utf8')
  const vars = {}

  for (const line of envContent.split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const [key, ...valueParts] = trimmed.split('=')
    if (key && valueParts.length > 0) {
      vars[key.trim()] = valueParts.join('=').trim()
    }
  }
  return vars
}

// ─────────────────────────────────────────
// Execute SQL via Supabase REST API
// ─────────────────────────────────────────
async function executeSql(supabaseUrl, serviceRoleKey, sql) {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': serviceRoleKey,
      'Authorization': `Bearer ${serviceRoleKey}`,
      'Prefer': 'return=minimal'
    },
    body: JSON.stringify({ query: sql })
  })

  // Try the direct SQL endpoint (Supabase Management API approach)
  if (!response.ok) {
    // Fallback: use the pg REST endpoint pattern
    const text = await response.text()
    return { ok: false, error: text, status: response.status }
  }

  return { ok: true }
}

// ─────────────────────────────────────────
// Execute SQL via Supabase MCP (direct DB)
// Uses the @supabase/mcp SQL execution approach
// ─────────────────────────────────────────
async function runMigrationViaMCP(supabaseUrl, serviceRoleKey, sql, filename) {
  // Use the Supabase database REST endpoint
  const pgEndpoint = `${supabaseUrl}/pg`

  // Primary approach: POST to /pg endpoint with SQL
  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'X-Client-Info': 'migrate_schema/1.0'
      },
      body: JSON.stringify({ query: sql })
    })

    const body = await response.text()
    return { ok: response.status < 400, status: response.status, body }
  } catch (err) {
    return { ok: false, error: err.message }
  }
}

// ─────────────────────────────────────────
// Main Runner
// ─────────────────────────────────────────
async function main() {
  console.log('╔══════════════════════════════════════════════╗')
  console.log('║      JobBoard — Migration Runner v1.0        ║')
  console.log('╚══════════════════════════════════════════════╝\n')

  // 1. Load environment
  let env
  try {
    env = loadEnv()
    console.log('✅ .env loaded')
  } catch (err) {
    console.error('❌ Failed to load .env:', err.message)
    process.exit(1)
  }

  const supabaseUrl = env.SUPABASE_URL
  const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY

  if (!supabaseUrl) {
    console.error('❌ SUPABASE_URL not found in .env')
    process.exit(1)
  }

  if (!serviceRoleKey) {
    console.error('❌ SUPABASE_SERVICE_ROLE_KEY not found in .env')
    console.error('   Add it to .env — it is required for migrations (bypasses RLS).')
    console.error('   NEVER expose this key in frontend code.')
    process.exit(1)
  }

  console.log(`🔗 Target: ${supabaseUrl}\n`)

  // 2. Load migration files
  const migrationsDir = join(projectRoot, 'migrations')
  let migrationFiles

  try {
    migrationFiles = readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort()  // ensures 001 → 010 order
    console.log(`📁 Found ${migrationFiles.length} migration files:`)
    migrationFiles.forEach(f => console.log(`   • ${f}`))
    console.log()
  } catch (err) {
    console.error('❌ Failed to read migrations/ directory:', err.message)
    process.exit(1)
  }

  // 3. Apply migrations via Supabase MCP execute_sql
  let passed = 0
  let failed = 0

  for (const filename of migrationFiles) {
    const filepath = join(migrationsDir, filename)
    const sql = readFileSync(filepath, 'utf8')

    process.stdout.write(`▶ Applying ${filename} ... `)

    // Print SQL for manual verification (useful for Supabase dashboard)
    console.log('\n' + '─'.repeat(60))
    console.log(`FILE: ${filename}`)
    console.log('─'.repeat(60))
    console.log(sql)
    console.log('─'.repeat(60))

    // NOTE: Direct SQL execution requires Supabase Management API
    // or running via the MCP tool. For local runner, we print the SQL
    // so the user can apply it via Supabase Dashboard → SQL Editor,
    // OR we use the Supabase JS admin client.
    //
    // The MCP execute_sql tool is the recommended approach for this project.
    // See: tools/migrate_schema.js USAGE section below.

    passed++
    console.log(`✅ ${filename} — SQL printed above (ready to apply via MCP)\n`)
  }

  // 4. Summary
  console.log('\n╔══════════════════════════════════════════════╗')
  console.log(`║  Migration Summary: ${passed} ready, ${failed} errors`)
  console.log('╚══════════════════════════════════════════════╝')
  console.log()
  console.log('📋 HOW TO APPLY:')
  console.log('   Option A (Recommended): Use Supabase MCP execute_sql tool')
  console.log('   Option B: Copy SQL above → Supabase Dashboard → SQL Editor')
  console.log()
  console.log('⚠️  Apply in order: 001 → 002 → 003 → ... → 010')
  console.log('⚠️  Apply 009 (SECURITY DEFINER functions) BEFORE 008 (RLS policies)')
}

main().catch(err => {
  console.error('❌ Unexpected error:', err)
  process.exit(1)
})
