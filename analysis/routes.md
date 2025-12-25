# Kitenga Whiro Repo Review

**Scan time:** 2025-12-24T18:53:03.928111
**Branch:** main
**Commit:** b6e517faa77bde813229644e2fb8bf5fe0a2e2b5
**Performed by:** run_repo_review.py

## Route Catalog
### Other

- GET /
- GET /.well-known/openapi-core.json
- GET /analysis/documents/latest
- GET /analysis/sync-status
- GET /api/events
- GET /api/kaitiaki
- GET /api/status
- GET /awa/memory/debug
- GET /debug/routes
- GET /gpt_connect.yaml
- GET /health
- GET /heartbeat
- GET /memory/ping
- GET /openai_tools.json
- GET /openapi-core.json
- GET /realm.json
- GET /status
- GET /tools/describe
- GET /tools/list
- POST /api/events
- POST /api/generate
- POST /api/kaitiaki
- POST /api/ocr
- POST /awa/loop/test
- POST /awa/memory/add
- POST /awa/memory/search
- POST /awa/protocol/event
- POST /gpt-whisper
- POST /ocr
- POST /scribe
- POST /speak
- POST /tools/call
- POST /translate

## External Context
- **Te Pō (`te_po/`)** handles FastAPI routes, assistant bridges, and vector + Supabase helpers—key envvars include `SUPABASE_SERVICE_ROLE_KEY`.
- **Kitenga MCP (`kitenga_mcp/`)** exposes `/mcp/*`, aggregates tool manifests, and front-ends Render/Supabase flows with `PIPELINE_TOKEN`/`RENDER_API_KEY` guardrails.
- **Vector + Logging**: `te_po/routes` + `kitenga_mcp/app_server.py` push embeddings, AwaNet events, and logs to Supabase buckets.

## MCP Tool Manifest Highlights
- Domains captured: none yet.
- No tool manifests yet.

## Script Tool Scan
- No keyword-matching scripts detected.

## Key Environment Variables
- `SUPABASE_SERVICE_ROLE_KEY`

## Mauri Summary
Flows stay connected: base routes + tool manifests are present, MCP/middleware checks guard bearer auth. Mauri score is 1/10 and growing.

## Notes for Agents
- `/analysis/` now holds JSON + Markdown review artifacts—MCP tool manifests should guide GPT Builder tooling.
- Follow the karakia cadence: start + finish, log to `/analysis/review_log_*.md`.

## Metadata
- Script: `analysis/run_repo_review.py`
- Versioned scan: yes

---
Author: awa developer (Kitenga Whiro [Adrian Hemi])
Protection: {"resource": "analysis_routes_md", "protected": false}
