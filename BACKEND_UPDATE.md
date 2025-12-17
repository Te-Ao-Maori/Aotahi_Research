## Backend Update Note (apply in main backend repo)

Use this to complete realm-scoped recall and assistant integration in the primary backend (not in this proxy/frontend repo).

### Required Files
1) `schema/realms.py`
- RealmConfig + RealmConfigLoader
- Load from env override (`REALM_CONFIG_PATH_<REALM>`) else `mauri/realms/{realm}/manifest.json`
- Cache configs; fail fast on missing/invalid manifest; expose `clear_cache()`

2) `utils/recall_service.py`
- `RecallService.recall(query, thread_id, top_k, vector_store)`
- OpenAI embeddings (`text-embedding-3-small`) with `OPENAI_API_KEY`
- Supabase pgvector search via `match_research_embeddings` RPC (default path)
- Log queries to `recall_logs` with `realm_id`
- Feature-flag OpenAI vector store search; do not leave `_search_openai()` as a placeholder. If not implemented, keep it disabled and rely on Supabase.

3) `routes/recall.py`
- `POST /{realm_id}/recall`
- Validate realm exists and `features.recall` is true
- Response: `matches[id, source, score, snippet, metadata], query_tokens, recall_latency_ms`
- 404 for unknown realm, 403 if recall disabled

4) `main.py`
- Import recall router; include once (`app.include_router(recall.router)`) to avoid duplicate route registration

5) `db/supabase.py` (or equivalent)
- `get_client()` using `SUPABASE_URL` / `SUPABASE_KEY`
- Helpers: `insert_with_realm(table, payload, realm_id)` and `select_by_realm(table, realm_id, limit)`

6) `.env.example` (backend)
- `REALM_CONFIG_PATH`
- `OPENAI_ASSISTANT_ID_RESEARCHER`, `OPENAI_VECTOR_STORE_ID_RESEARCHER`
- `OPENAI_ASSISTANT_ID_TRANSLATOR`, `OPENAI_VECTOR_STORE_ID_TRANSLATOR`
- `SUPABASE_URL`, `SUPABASE_KEY`
- Existing: `TE_PO_URL`, `BEARER_KEY`, `REALM_ID`
- Keep one canonical upstream var (`TE_PO_URL`) for proxy/backend calls

### Migrations (Supabase)
- Apply `migrations/001_realm_tables.sql` (research_sessions/notes/chunks/embeddings; translations/logs; pronunciation_cache; all with realm_id).
- Add `migrations/002_recall_logs.sql`:
  ```sql
  CREATE TABLE IF NOT EXISTS recall_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    realm_id TEXT NOT NULL,
    query TEXT NOT NULL,
    results_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_recall_logs_realm ON recall_logs(realm_id);
  ```
- Ensure pgvector: `CREATE EXTENSION IF NOT EXISTS vector;`
- RPC needed by recall: `match_research_embeddings(query_embedding vector, match_count int, filter_realm_id text)` returning `chunk_id, source_id, content, similarity, metadata` filtered by realm_id.

### Realm Manifests
- Ensure `mauri/realms/researcher/manifest.json` and `mauri/realms/translator/manifest.json` exist and are loaded by RealmConfigLoader; populate assistant/vector IDs and Supabase info.

### Frontend Touchpoints
- Chat/recall flows should call `/{realmId}/recall` (not `/vector/search`), sending `{query, thread_id, top_k, vector_store}` and building context from `response.matches[*].snippet`.

### Render / Deployment Env (backend)
- `REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json`
- `OPENAI_API_KEY`, `SUPABASE_URL`, `SUPABASE_KEY`
- `OPENAI_ASSISTANT_ID_RESEARCHER`, `OPENAI_VECTOR_STORE_ID_RESEARCHER`
- `OPENAI_ASSISTANT_ID_TRANSLATOR`, `OPENAI_VECTOR_STORE_ID_TRANSLATOR`
- `BEARER_KEY`, `REALM_ID`, `TE_PO_URL`
