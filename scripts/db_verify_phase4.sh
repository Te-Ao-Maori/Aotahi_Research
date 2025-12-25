#!/usr/bin/env bash
set -euo pipefail

# scripts/db_verify_phase4.sh
ENV_FILE="${1:-.env}"

if [[ -f "$ENV_FILE" ]]; then
  export $(grep -v '^\s*#' "$ENV_FILE" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | xargs -d '\n')
fi

DB_URL="${DATABASE_URL:-${SUPABASE_DB_URL:-}}"
if [[ -z "${DB_URL}" ]]; then
  echo "ERROR: Set DATABASE_URL (or SUPABASE_DB_URL) in $ENV_FILE"
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found. Install Postgres client tools."
  exit 1
fi

echo "Running Phase 4 pgvector verification..."
psql "$DB_URL" -v ON_ERROR_STOP=1 -f "scripts/sql/phase4_verify.sql"
echo "✅ Phase 4 done."
