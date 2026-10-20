#!/usr/bin/env python3
"""
tools/verify_supabase.py
========================
Phase 2 — LINK Handshake Tool
Purpose: Verify Supabase connectivity before any schema or frontend work begins.

Checks:
  1. .env file is present and keys are populated
  2. Supabase REST API responds (GET /rest/v1/ with anon key)
  3. Supabase Auth endpoint is reachable
  4. Reports project status

Usage:
  python tools/verify_supabase.py

Self-Annealing: If this fails, check findings.md Section 4 before guessing.
"""

import os
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent.parent
ENV_FILE = ROOT / ".env"

PASS = "✅"
FAIL = "❌"
WARN = "⚠️ "

# ── Helpers ──────────────────────────────────────────────────────────────────

def load_env(path: Path) -> dict:
    """Parse a .env file into a dict. Skips comments and blank lines."""
    env = {}
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, val = line.partition("=")
            env[key.strip()] = val.strip()
    return env


def http_get(url: str, headers: dict) -> tuple[int, dict | str]:
    """Simple HTTP GET. Returns (status_code, body)."""
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(raw)
            except json.JSONDecodeError:
                return resp.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw
    except urllib.error.URLError as e:
        return 0, str(e.reason)


def check(label: str, condition: bool, detail: str = "") -> bool:
    icon = PASS if condition else FAIL
    print(f"  {icon}  {label}" + (f"  →  {detail}" if detail else ""))
    return condition


# ── Main Verification ─────────────────────────────────────────────────────────

def main():
    print("\n" + "═" * 60)
    print("  🔗 B.L.A.S.T. Phase 2 — Link Verification")
    print("  Project: jethjobs | Supabase ap-northeast-1")
    print("═" * 60 + "\n")

    all_passed = True

    # ── Step 1: .env exists ────────────────────────────────────────────────
    print("[ Step 1 ] .env File Check")
    env_exists = ENV_FILE.exists()
    all_passed &= check(".env file present", env_exists, str(ENV_FILE) if env_exists else "NOT FOUND")

    if not env_exists:
        print(f"\n  {FAIL}  Cannot proceed — .env is missing. Run from project root.\n")
        sys.exit(1)

    env = load_env(ENV_FILE)

    url_ok = bool(env.get("SUPABASE_URL", "").startswith("https://"))
    key_ok  = len(env.get("SUPABASE_ANON_KEY", "")) > 20

    all_passed &= check("SUPABASE_URL populated",      url_ok,  env.get("SUPABASE_URL", "MISSING"))
    all_passed &= check("SUPABASE_ANON_KEY populated", key_ok,  "***" + env["SUPABASE_ANON_KEY"][-8:] if key_ok else "MISSING")

    service_role_exposed = "SUPABASE_SERVICE_ROLE_KEY" in env
    if service_role_exposed:
        print(f"  {WARN}  SUPABASE_SERVICE_ROLE_KEY found in .env — ensure it is NEVER sent to the frontend!")

    print()

    # ── Step 2: REST API health ────────────────────────────────────────────
    print("[ Step 2 ] Supabase REST API Health Check")
    supabase_url = env["SUPABASE_URL"]
    anon_key     = env["SUPABASE_ANON_KEY"]

    rest_url = f"{supabase_url}/rest/v1/"
    headers  = {
        "apikey":        anon_key,
        "Authorization": f"Bearer {anon_key}",
        "Content-Type":  "application/json",
    }

    status, body = http_get(rest_url, headers)
    rest_ok = status == 200
    all_passed &= check("REST API responds (GET /rest/v1/)", rest_ok, f"HTTP {status}")

    if not rest_ok:
        print(f"         Response: {body}")

    print()

    # ── Step 3: Auth endpoint ─────────────────────────────────────────────
    print("[ Step 3 ] Supabase Auth Endpoint Check")
    auth_url = f"{supabase_url}/auth/v1/health"
    status2, body2 = http_get(auth_url, {"apikey": anon_key})
    auth_ok = status2 == 200
    all_passed &= check("Auth endpoint reachable (/auth/v1/health)", auth_ok, f"HTTP {status2}")

    if auth_ok and isinstance(body2, dict):
        check("Auth service status", body2.get("status") == "ok", body2.get("status", "unknown"))

    print()

    # ── Step 4: Storage endpoint ───────────────────────────────────────────
    print("[ Step 4 ] Supabase Storage Endpoint Check")
    storage_url = f"{supabase_url}/storage/v1/health"
    status3, body3 = http_get(storage_url, {"apikey": anon_key})
    storage_ok = status3 == 200
    all_passed &= check("Storage endpoint reachable (/storage/v1/health)", storage_ok, f"HTTP {status3}")

    print()

    # ── Summary ────────────────────────────────────────────────────────────
    print("═" * 60)
    if all_passed:
        print(f"  {PASS}  ALL CHECKS PASSED — Phase 2: Link VERIFIED")
        print("  Gate is OPEN. Safe to proceed to Phase 3: Architect.")
    else:
        print(f"  {FAIL}  ONE OR MORE CHECKS FAILED")
        print("  DO NOT proceed. Fix failures above, then re-run.")
        print("  Log errors in findings.md Section 4 (Self-Annealing Log).")
        sys.exit(1)
    print("═" * 60 + "\n")


if __name__ == "__main__":
    main()
