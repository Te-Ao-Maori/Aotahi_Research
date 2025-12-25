#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env}"

if [[ -f "$ENV_FILE" ]]; then
  export $(grep -v '^\s*#' "$ENV_FILE" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | xargs -d '\n')
fi

BASE_URL="${BACKEND_BASE_URL:-http://localhost:8000}"

# Required for recall per your checklist
BEARER_KEY="${BEARER_KEY:-}"
if [[ -z "$BEARER_KEY" ]]; then
  echo "ERROR: BEARER_KEY is not set (needed for /{realm}/recall)."
  exit 1
fi

echo "== Phase 6 smoke: ${BASE_URL} =="

echo "--- /health (expect 200)"
curl -sS -D /tmp/health_headers.txt "${BASE_URL}/health" -o /tmp/health_body.txt
head -n 5 /tmp/health_headers.txt
echo
head -c 2000 /tmp/health_body.txt; echo; echo

echo "--- /researcher/manifest (expect 200)"
curl -sS -D /tmp/r_manifest_headers.txt "${BASE_URL}/researcher/manifest" -o /tmp/r_manifest_body.txt
head -n 5 /tmp/r_manifest_headers.txt
echo
head -c 2000 /tmp/r_manifest_body.txt; echo; echo

echo "--- /translator/manifest (expect 200)"
curl -sS -D /tmp/t_manifest_headers.txt "${BASE_URL}/translator/manifest" -o /tmp/t_manifest_body.txt
head -n 5 /tmp/t_manifest_headers.txt
echo
head -c 2000 /tmp/t_manifest_body.txt; echo; echo

echo "--- /researcher/recall (expect 200; schema includes matches/query_tokens/recall_latency_ms)"
curl -sS -D /tmp/r_recall_headers.txt -X POST "${BASE_URL}/researcher/recall" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${BEARER_KEY}" \
  -d '{
    "query": "kōrero about kaitiakitanga",
    "thread_id": "thread_test_123",
    "top_k": 5,
    "vector_store": "openai"
  }' \
  -o /tmp/r_recall_body.txt

head -n 5 /tmp/r_recall_headers.txt
echo
head -c 3000 /tmp/r_recall_body.txt; echo; echo

# Lightweight schema presence checks (no jq dependency)
for key in "\"matches\"" "\"query_tokens\"" "\"recall_latency_ms\""; do
  if ! grep -q "${key}" /tmp/r_recall_body.txt; then
    echo "ERROR: researcher recall response missing key: ${key}"
    exit 1
  fi
done
if grep -q "\"query_tokens\"[[:space:]]*:[[:space:]]*0" /tmp/r_recall_body.txt; then
  echo "ERROR: query_tokens is 0 (expected > 0 if embedding worked)"
  exit 1
fi

echo "--- /translator/recall (expect 403 Forbidden)"
HTTP_CODE="$(curl -sS -o /tmp/t_recall_body.txt -w "%{http_code}" -X POST "${BASE_URL}/translator/recall" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${BEARER_KEY}" \
  -d '{
    "query": "kōrero about kaitiakitanga",
    "thread_id": "thread_test_123",
    "top_k": 5,
    "vector_store": "openai"
  }')"

echo "translator recall HTTP ${HTTP_CODE}"
if [[ "${HTTP_CODE}" != "403" ]]; then
  echo "Body:"
  head -c 2000 /tmp/t_recall_body.txt; echo
  echo "ERROR: expected 403 for translator recall"
  exit 1
fi

echo "✅ Phase 6 backend smoke passed"

# Optional: Supabase REST checks (only if env vars present)
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_KEY="${SUPABASE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"

if [[ -n "${SUPABASE_URL}" && -n "${SUPABASE_KEY}" ]]; then
  echo
  echo "== Optional Supabase REST checks =="

  # Insert a row (idempotency depends on your schema; this is “best effort”)
  echo "--- Insert test row into research_sessions (best effort)"
  curl -sS -o /tmp/supa_insert.txt -w "HTTP %{http_code}\n" \
    -X POST "${SUPABASE_URL}/rest/v1/research_sessions" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "realm_id": "researcher",
      "user_id": "test_user",
      "thread_id": "thread_abc123",
      "assistant_id": "asst_researcher_xxxxx",
      "vector_store_id": "vs_researcher_xxxxx"
    }'
  head -c 2000 /tmp/supa_insert.txt; echo

  echo "--- Query research_sessions?realm_id=eq.researcher (expect >= 1 row)"
  curl -sS "${SUPABASE_URL}/rest/v1/research_sessions?realm_id=eq.researcher&select=realm_id,user_id,thread_id" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" \
    | head -c 3000; echo

  echo "--- Query translations table (expect separate table; often 0 rows)"
  curl -sS "${SUPABASE_URL}/rest/v1/translations?select=*" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" \
    | head -c 2000; echo

  echo "✅ Optional Supabase checks executed (interpret results based on RLS + schema)"
else
  echo
  echo "(Skipping Supabase REST checks: SUPABASE_URL and SUPABASE_KEY not both set)"
fi
