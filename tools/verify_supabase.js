#!/usr/bin/env node
/**
 * tools/verify_supabase.js
 * ========================
 * Phase 2 — LINK Handshake Tool
 * Purpose: Verify Supabase connectivity before any schema or frontend work begins.
 *
 * Checks:
 *   1. .env file is present and keys are populated
 *   2. Supabase Auth endpoint responds (HTTP 200)
 *   3. Supabase Storage endpoint responds (HTTP 200)
 *   4. PostgreSQL DB responds via a direct REST table query
 *
 * Usage:
 *   node tools/verify_supabase.js
 *
 * Runtime: Node.js v22+ (no external dependencies)
 */

const https = require("https");
const fs = require("fs");
const path = require("path");

// ── Config ────────────────────────────────────────────────────────────────────
const ROOT = path.resolve(__dirname, "..");
const ENV_FILE = path.join(ROOT, ".env");

const PASS = "✅";
const FAIL = "❌";
const WARN = "⚠️ ";

// ── Helpers ───────────────────────────────────────────────────────────────────

function loadEnv(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const env = {};
  for (const line of fs.readFileSync(filePath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx === -1) continue;
    env[trimmed.slice(0, idx).trim()] = trimmed.slice(idx + 1).trim();
  }
  return env;
}

function httpGet(hostname, path, headers) {
  return new Promise((resolve) => {
    const opts = { hostname, path, headers, timeout: 10000 };
    https
      .get(opts, (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => resolve({ status: res.statusCode, body: data }));
      })
      .on("error", (e) => resolve({ status: 0, body: e.message }))
      .on("timeout", () => resolve({ status: 0, body: "TIMEOUT" }));
  });
}

function check(label, condition, detail = "") {
  const icon = condition ? PASS : FAIL;
  console.log(`  ${icon}  ${label}${detail ? `  →  ${detail}` : ""}`);
  return condition;
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log("");
  console.log("════════════════════════════════════════════════════════════");
  console.log("  🔗 B.L.A.S.T. Phase 2 — Link Verification");
  console.log("  Project: jethjobs  |  Supabase ap-northeast-1 (Tokyo)");
  console.log("════════════════════════════════════════════════════════════");
  console.log("");

  let allPassed = true;

  // ── Step 1: .env ─────────────────────────────────────────────────────────
  console.log("[ Step 1 ] .env File Check");
  const envExists = fs.existsSync(ENV_FILE);
  allPassed &= check(".env file present", envExists, envExists ? ENV_FILE : "NOT FOUND");

  if (!envExists) {
    console.log(`\n  ${FAIL}  Cannot proceed — .env is missing.\n`);
    process.exit(1);
  }

  const env = loadEnv(ENV_FILE);
  const urlOk = env.SUPABASE_URL?.startsWith("https://");
  const keyOk = (env.SUPABASE_ANON_KEY?.length ?? 0) > 20;

  allPassed &= check("SUPABASE_URL populated",      urlOk, env.SUPABASE_URL ?? "MISSING");
  allPassed &= check("SUPABASE_ANON_KEY populated", keyOk, keyOk ? "***" + env.SUPABASE_ANON_KEY.slice(-8) : "MISSING");

  if (env.SUPABASE_SERVICE_ROLE_KEY) {
    console.log(`  ${WARN}  SERVICE_ROLE_KEY found in .env — ensure it is NEVER sent to the frontend!`);
  }

  console.log("");
  const hostname = new URL(env.SUPABASE_URL).hostname;
  const key = env.SUPABASE_ANON_KEY;

  // ── Step 2: Auth ──────────────────────────────────────────────────────────
  console.log("[ Step 2 ] Supabase Auth Endpoint");
  const auth = await httpGet(hostname, "/auth/v1/health", { apikey: key });
  allPassed &= check("Auth health (/auth/v1/health)", auth.status === 200, `HTTP ${auth.status}`);
  console.log("");

  // ── Step 3: Storage ───────────────────────────────────────────────────────
  console.log("[ Step 3 ] Supabase Storage Endpoint");
  const storage = await httpGet(hostname, "/storage/v1/health", { apikey: key, Authorization: `Bearer ${key}` });
  allPassed &= check("Storage health (/storage/v1/health)", storage.status === 200, `HTTP ${storage.status}`);
  console.log("");

  // ── Step 4: REST API (anon-accessible table probe) ────────────────────────
  // NOTE: GET /rest/v1/ root requires service_role key (returns 401 with anon key).
  // We probe a table that will exist post-migration. Before migration, expect 404
  // (table not found) — that still proves REST connectivity is working.
  console.log("[ Step 4 ] Supabase REST API Connectivity");
  const rest = await httpGet(hostname, "/rest/v1/profiles", {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  });
  const restReachable = rest.status === 200 || rest.status === 404 || rest.status === 406;
  allPassed &= check(
    "REST API reachable (/rest/v1/profiles)",
    restReachable,
    `HTTP ${rest.status}${rest.status === 404 ? " (table not yet created — OK before migration)" : ""}`
  );
  console.log("");

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log("════════════════════════════════════════════════════════════");
  if (allPassed) {
    console.log(`  ${PASS}  ALL CHECKS PASSED — Phase 2: Link VERIFIED`);
    console.log("  Gate is OPEN. Safe to proceed to Phase 3: Architect.");
  } else {
    console.log(`  ${FAIL}  ONE OR MORE CHECKS FAILED`);
    console.log("  DO NOT proceed. Fix failures, then re-run.");
    console.log("  Log errors in findings.md → Section 5 (Self-Annealing).");
    process.exit(1);
  }
  console.log("════════════════════════════════════════════════════════════");
  console.log("");
}

main();
