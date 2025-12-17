# Codex Review Prompt: Realm-Scoped Assistant & Vector Store Implementation

Copy and paste this prompt to Codex to get a focused, minimal patch set without full refactoring.

---

## Task

You are reviewing the Aotahi Research Portal codebase for implementation of realm-scoped OpenAI Assistant and Vector Store architecture, with a focus on preventing cross-contamination between the Researcher and Translator cards.

**Constraints:**
- Do NOT refactor unrelated files (e.g., DevUI panels, styling, or UI components).
- Do NOT rewrite existing routes or endpoints.
- Focus ONLY on the minimum patch set needed to:
  1. Add realm-scoped Assistant + Vector Store config
  2. Implement a single `/{realm_id}/recall` gateway endpoint
  3. Ensure backend reconnects to Render without duplicate routes
  4. Add realm-scoped Supabase tables (migration instructions)

---

## Repository Structure & Current State

The repo is at `/workspaces/Aotahi_Research/` with:

- **Frontend:** `te_ao/` (React + Vite, runs on port 5000)
- **Proxy:** `te_po_proxy/` (FastAPI, forwards all requests to backend on port 8100)
- **Backend:** External service on port 8000 (Render or local)
- **Realm Config:** `mauri/realm_manifest.json` (currently minimal, no per-realm settings)
- **Database:** Supabase (currently used for documents, memory, etc.)

### Current API Calls (from Frontend)

**Researcher Realm:**
- `POST /research/stacked` – Research pipeline
- `POST /vector/search` – Vector search (needs recall gateway)
- `POST /kitenga/ask` – Assistant chat
- `POST /kitenga/gpt-whisper` – Streaming chat
- `GET /documents/profiles` – List documents

**Translator Realm:**
- `POST /reo/translate` – Translation
- `POST /reo/explain` – Explanation
- `POST /reo/pronounce` – Pronunciation

**All Realms:**
- `GET /health` – Health check

### Environment (Current)

From project files, these are active:
- `TE_PO_URL=http://localhost:8000` (backend)
- `BEARER_KEY=test-token` (auth for proxy)
- `REALM_ID=maori_research` (global, not per-realm)
- `PROXY_PORT=8100` (proxy)

---

## Tight Blueprint (Reference)

See `REALM_BLUEPRINT.md` in the repo root for full details. Key points:

### 1. Realm Configuration
Store per-realm config at `mauri/realms/{realm_id}/manifest.json`:
```json
{
  "realm_id": "researcher",
  "openai": {
    "assistant_id": "asst_researcher_xxxxx",
    "vector_store_id": "vs_researcher_xxxxx"
  },
  "supabase": { /* optional */ },
  "features": { "vector_search": true, "recall": true }
}
```

### 2. Supabase Schema (Minimum Tables)

**Researcher:**
- `research_sessions` (thread_id, assistant_id, vector_store_id, realm_id)
- `research_notes` (summaries, citations, realm_id)
- `research_chunks` (optional, realm_id)

**Translator:**
- `translations` (source_text, target_text, realm_id, dialect, model, confidence)
- `translation_logs` (translation_id, request_tokens, response_tokens, latency_ms, realm_id)
- `pronunciation_cache` (text, ipa_phonetic, audio_url, realm_id)

All tables **MUST** include `realm_id` column and index on it.

### 3. Recall Gateway Endpoint

New endpoint `POST /{realm_id}/recall`:
```json
Request: { "query": "...", "thread_id": "optional", "top_k": 5, "vector_store": "openai|supabase|both" }
Response: { "matches": [{ "id": "...", "source": "...", "score": 0.92, "snippet": "...", "metadata": {...} }], "query_tokens": 12, "recall_latency_ms": 145 }
```

Implements:
- Load realm config from `mauri/realms/{realm_id}/manifest.json`
- Embed query via OpenAI Embeddings
- Search OpenAI vector store (if configured)
- Search Supabase pgvector (if configured)
- Merge & rank results
- Log query + results to Supabase
- Return formatted matches

### 4. Chat Pipeline Update (Minimal)

When user asks a question:
1. **Recall** via `POST /{realm_id}/recall` (instead of scattered `/vector/search` calls)
2. **Compose** context from recall results
3. **Call Assistant** with thread_id
4. **Save** results + citations to Supabase (`research_notes` or `translations`)

---

## Deliverables (Exact List)

Provide a **numbered list of files to change**, followed by **exact code diffs** for each file. For new files, show the full content.

### Expected Output Format

```
## Files to Change

1. mauri/realms/researcher/manifest.json (NEW)
2. mauri/realms/translator/manifest.json (NEW)
3. {backend}/routes/recall.py (NEW)
4. {backend}/schema/realms.py (NEW)
5. {backend}/db/supabase.py (MODIFY to add realm_id support)
6. {backend}/.env.example (MODIFY)
7. {backend}/main.py (MODIFY if routing needed)
8. {frontend}/src/panels/ChatPanel.jsx (MODIFY to use recall gateway)
9. Supabase migration SQL (NEW)

## Code Changes

### 1. mauri/realms/researcher/manifest.json (NEW)
\`\`\`json
{ ... }
\`\`\`

### 2. {backend}/routes/recall.py (NEW)
\`\`\`python
... full code ...
\`\`\`

... etc for each file
```

---

## Constraints & Guardrails

✅ **DO:**
- Add new files (`recall.py`, realm configs, migrations)
- Modify existing backend routes to support realm_id parameter
- Add realm_id column to Supabase table insert/update operations
- Update `.env.example` with new realm-scoped variables
- Show Supabase SQL migration commands

❌ **DON'T:**
- Refactor `te_ao/src/devui/` or dev panels
- Change styling or UI components
- Move or rename existing endpoints
- Rewrite `ChatPanel.jsx` wholesale; minimal changes only
- Change proxy (`te_po_proxy/main.py`) logic

---

## Key Questions for Codex

1. **Identify existing routes:** Scan the repo and list all routes in `{backend}` that handle: `chat`, `kitenga`, `research`, `vector`, `reo`, `documents`. Show the file + route definition for each.

2. **Identify recall logic:** Where is vector search / retrieval currently implemented? (e.g., in `/vector/search` or in `/kitenga/gpt-whisper`)? Show the current code.

3. **Database pattern:** How are Supabase tables currently queried? (e.g., `supabase.table('documents').select(...)`). Show one example query.

4. **Realm ID passage:** How does realm_id currently flow through the backend? Is it in headers, URL path, or environment?

5. **Output:** For each file change, provide:
   - File path (relative to repo root)
   - **FULL file content** for new files
   - **Exact diff** for modified files (3-5 lines of context before/after each change)
   - Explanation of each change (1-2 sentences)

---

## Environment & Render Setup

After implementation, the backend on Render should be deployable with:

```
REALM_ID=researcher
REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json
OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx
OPENAI_ASSISTANT_ID_TRANSLATOR=asst_yyyyy
OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_yyyyy
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_KEY=eyJxxxx
```

Existing routes (`/reo/translate`, `/kitenga/ask`, etc.) should work unchanged.

---

## Summary for Codex

You are a code review agent. Your goal is to:

1. **Map** all current routes, database patterns, and realm ID usage
2. **Propose** the minimum patch set (new files + targeted edits) to enable:
   - Realm-scoped Assistant & Vector Store config
   - Single `/{realm_id}/recall` gateway
   - Realm-scoped Supabase tables
3. **Ensure** no duplicate routes, consistent request/response schemas, and proper realm isolation
4. **Output** a numbered list of files + exact code diffs (no refactoring, no rewrites)

**You do NOT need to implement anything.** Just scan the repo, identify the changes needed, and provide the exact diffs for the user to apply.

---

## Acceptance Criteria

- [ ] All route mappings identified and listed
- [ ] Recall logic identified and current implementation shown
- [ ] Database query pattern documented (with example)
- [ ] Files to change = exact list with paths
- [ ] Each file change = numbered with explanation + exact diff or full content
- [ ] No unrelated files touched
- [ ] `.env.example` updated with realm-scoped variables
- [ ] Supabase migration SQL provided (runnable commands)
- [ ] Render deployment env vars documented

---

**Ready for Codex. Copy this entire prompt and send it as the task.**
