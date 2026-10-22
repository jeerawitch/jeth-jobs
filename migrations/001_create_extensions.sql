-- ============================================================
-- Migration 001: Enable Required Extensions
-- ============================================================
-- Run this FIRST before any other migration.

-- uuid-ossp: for gen_random_uuid() (fallback; pgcrypto preferred)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- pgcrypto: for gen_random_uuid() in PostgreSQL 13+
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
