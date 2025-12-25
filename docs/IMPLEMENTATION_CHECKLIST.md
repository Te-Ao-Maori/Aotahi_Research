# Implementation Checklist: Realm-Scoped Isolation

Use this checklist to track progress as you implement the blueprint.

---

## Phase 1: Preparation ✋ (You are here)

- [x] Read REALM_BLUEPRINT.md
- [x] Review ARCHITECTURE_DIAGRAMS.md
- [x] Review IMPLEMENTATION_EXAMPLES.md
- [x] Review CODEX_REVIEW_PROMPT.md
- [x] Review ENV_SETUP_GUIDE.md
- [ ] Gather OpenAI Assistant IDs:
  - [x] Researcher realm assistant_id
  - [x] Researcher realm vector_store_id
  - [ ] Translator realm assistant_id
  - [ ] Translator realm vector_store_id
- [ ] Verify Supabase admin access
- [ ] Verify Render access (if deploying to production)

---

## Phase 2: Codex Review 🤖

- [x] Copy CODEX_REVIEW_PROMPT.md entirely
- [x] Send to Codex with task: "Review and scan this codebase"
- [x] Codex returns:
  - [x] List of existing routes (kitenga, reo, vector, research, documents)
  - [x] Current vector search implementation location
  - [x] Database query pattern (how Supabase is currently used)
  - [x] Files to change (numbered list)
  - [x] Exact code diffs for each file
  - [x] Updated .env.example
- [x] Review Codex output:
  - [x] Verify file paths are correct (check repo)
  - [x] Verify diffs make sense (test mentally)
  - [x] Ask clarifying questions if needed
  - [x] Request adjustments if necessary

---

## Phase 3: Backend Implementation 🔨

### Part A: Create/Modify Files
- [x] Create `schema/realms.py` (RealmConfigLoader)
  - [x] Test: Load researcher manifest
  - [x] Test: Load translator manifest
  - [x] Test: Cache is working
  - [x] Test: Error handling for missing files
- [x] Create `utils/recall_service.py` (RecallService)
  - [x] Test: Embed query via OpenAI
  - [x] Test: Search OpenAI vector store (if available)
  - [x] Test: Search Supabase pgvector (if available)
  - [x] Test: Merge + deduplicate results
  - [x] Test: Logging to Supabase
- [x] Create `routes/recall.py` (recall endpoint)
  - [x] Test: POST /researcher/recall (200)
  - [x] Test: POST /translator/recall (200)
  - [x] Test: Invalid realm_id (404)
  - [x] Test: Realm with recall disabled (403)
  - [x] Test: Response schema matches spec
- [x] Modify `main.py`:
  - [x] Import recall router
  - [x] Register recall router: `app.include_router(recall.router)`
  - [x] Test: Backend starts without errors

### Part B: Environment Variables
- [x] Update `.env.example`:
  - [x] Add REALM_ID
  - [x] Add REALM_CONFIG_PATH
  - [x] Add OPENAI_ASSISTANT_ID_RESEARCHER
  - [x] Add OPENAI_VECTOR_STORE_ID_RESEARCHER
  - [x] Add OPENAI_ASSISTANT_ID_TRANSLATOR
  - [x] Add OPENAI_VECTOR_STORE_ID_TRANSLATOR
- [x] Create local `.env`:
  - [x] Copy from .env.example
  - [x] Fill in actual OpenAI IDs
  - [x] Fill in Supabase URL + key
  - [x] Test: `echo $OPENAI_ASSISTANT_ID_RESEARCHER` returns correct ID

---

## Phase 4: Database Setup 🗄️

- [ ] Enable pgvector extension (if using Supabase pgvector):
  - [ ] Go to Supabase dashboard → SQL Editor
  - [ ] Run: `CREATE EXTENSION IF NOT EXISTS vector;`
  - [ ] Verify: Extension enabled
- [ ] Run migration: `migrations/001_realm_tables.sql`
  - [ ] Create research_sessions table
  - [ ] Create research_notes table
  - [ ] Create research_chunks table (optional)
  - [ ] Create research_embeddings table (optional)
  - [ ] Create translations table
  - [ ] Create translation_logs table
  - [ ] Create pronunciation_cache table
  - [ ] Verify: All tables exist in Supabase
  - [ ] Verify: All have realm_id column
  - [ ] Verify: Indexes created
- [ ] Create Supabase pgvector search function (if using):
  - [ ] Create `match_research_embeddings()` function
  - [ ] Test: Run sample query
- [ ] Set RLS policies (optional but recommended):
  - [ ] Each table has policy: "realm_id = current_user_realm_id"
  - [ ] Test: User can only see their realm's data

---

## Phase 5: Realm Configuration 📋

- [ ] Fill in `mauri/realms/researcher/manifest.json`:
  - [ ] realm_id = "researcher"
  - [ ] openai.assistant_id = asst_researcher_xxxxx
  - [ ] openai.vector_store_id = vs_researcher_xxxxx
  - [ ] supabase.project_url = https://xxxx.supabase.co
  - [ ] supabase.anon_key = eyJ...
  - [ ] features.recall = true
  - [ ] Test: RealmConfigLoader can load it
- [ ] Fill in `mauri/realms/translator/manifest.json`:
  - [ ] realm_id = "translator"
  - [ ] openai.assistant_id = asst_translator_yyyyy
  - [ ] openai.vector_store_id = vs_translator_yyyyy
  - [ ] supabase.project_url = https://xxxx.supabase.co
  - [ ] supabase.anon_key = eyJ...
  - [ ] features.recall = false (translations don't use recall)
  - [ ] Test: RealmConfigLoader can load it

---

## Phase 6: Local Testing 🧪

### Backend Connectivity
- [ ] Backend starts: `python -m uvicorn main:app --reload`
  - [ ] No import errors
  - [ ] No missing env vars errors
  - [ ] Server listening on port 8000
- [ ] Health check: `curl http://localhost:8000/health`
  - [ ] Response: 200 OK
  - [ ] Body contains realm_id

### Realm Config Loading
- [ ] Test researcher config:
  ```bash
  curl http://localhost:8000/researcher/manifest
  # Should return researcher manifest
  ```
- [ ] Test translator config:
  ```bash
  curl http://localhost:8000/translator/manifest
  # Should return translator manifest
  ```

### Recall Endpoint (Researcher)
- [ ] POST /researcher/recall:
  ```bash
  curl -X POST http://localhost:8000/researcher/recall \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $BEARER_KEY" \
    -d '{
      "query": "kōrero about kaitiakitanga",
      "thread_id": "thread_test_123",
      "top_k": 5,
      "vector_store": "openai"
    }'
  # Should return: { "matches": [...], "query_tokens": X, "recall_latency_ms": Y }
  ```
- [ ] Verify response schema (matches, query_tokens, latency_ms)
- [ ] Verify query_tokens is > 0 (OpenAI embedding worked)

### Recall Endpoint (Translator)
- [ ] POST /translator/recall (should fail):
  ```bash
  curl -X POST http://localhost:8000/translator/recall ...
  # Should return: 403 Forbidden (recall disabled)
  ```

### Database Queries
- [ ] Insert test data:
  ```bash
  # Insert into research_sessions (researcher realm)
  curl -X POST https://xxxx.supabase.co/rest/v1/research_sessions \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "realm_id": "researcher",
      "user_id": "test_user",
      "thread_id": "thread_abc123",
      "assistant_id": "asst_researcher_xxxxx",
      "vector_store_id": "vs_researcher_xxxxx"
    }'
  ```
- [ ] Query researcher data:
  ```bash
  curl -X GET "https://xxxx.supabase.co/rest/v1/research_sessions?realm_id=eq.researcher" \
    -H "Authorization: Bearer $SUPABASE_KEY"
  # Should return 1 row
  ```
- [ ] Verify realm isolation:
  ```bash
  curl -X GET "https://xxxx.supabase.co/rest/v1/research_sessions" \
    -H "Authorization: Bearer $SUPABASE_KEY"
  # Should return 1 row (with realm_id=researcher)
  
  curl -X GET "https://xxxx.supabase.co/rest/v1/translations" \
    -H "Authorization: Bearer $SUPABASE_KEY"
  # Should return 0 rows (translations table is separate)
  ```

---

## Phase 7: Frontend Integration 🎨

- [ ] Modify `src/panels/ChatPanel.jsx`:
  - [ ] Get realm_id (from context, state, or hardcoded as "researcher")
  - [ ] Replace `/vector/search` with `/{realm_id}/recall`
  - [ ] Update request body:
    - [ ] Add "thread_id"
    - [ ] Add "top_k"
    - [ ] Add "vector_store"
  - [ ] Parse recall response:
    ```javascript
    // OLD: const results = response.results
    // NEW:
    const matches = response.matches;
    const context = matches
      .map(m => `${m.source}: ${m.snippet}`)
      .join("\n\n");
    ```
  - [ ] Test: Frontend loads without errors

- [ ] Test Chat Flow (Researcher Realm):
  - [ ] User types: "Tell me about kōrero"
  - [ ] Click: [Send]
  - [ ] Frontend calls `POST /researcher/recall`
  - [ ] Backend returns matches
  - [ ] Frontend displays matches in chat
  - [ ] Assistant responds based on context
  - [ ] Chat saves to research_notes table

- [ ] Verify No Cross-Contamination:
  - [ ] Recall returns only researcher data (not translations)
  - [ ] Chat history is saved to research_sessions, not translations table

---

## Phase 8: Proxy Testing 🔄

- [ ] Proxy running: `python -m uvicorn main:app --host 0.0.0.0 --port 8100`
- [ ] Test proxy forwards to backend:
  ```bash
  curl http://localhost:8100/researcher/recall \
    -H "Authorization: Bearer $BEARER_KEY" \
    -d '{"query": "test"}'
  # Should forward to http://localhost:8000/researcher/recall
  ```
- [ ] Verify headers are passed through
- [ ] Verify Bearer token is injected

---

## Phase 9: Render Deployment 🚀

### Pre-Deployment Checklist
- [ ] All local tests pass
- [ ] No hardcoded secrets in code
- [ ] .env.example is up-to-date
- [ ] Git is clean (no uncommitted changes)
- [ ] Backend code is committed

### Render Setup
- [ ] Create new Render service (or update existing)
  - [ ] Name: `aotahi-researcher` (or appropriate name)
  - [ ] Environment: Python
  - [ ] Build command: `pip install -r requirements.txt`
  - [ ] Start command: `python -m uvicorn main:app --host 0.0.0.0 --port $PORT`

### Environment Variables on Render
- [ ] Add OPENAI_API_KEY
- [ ] Add OPENAI_ASSISTANT_ID_RESEARCHER
- [ ] Add OPENAI_VECTOR_STORE_ID_RESEARCHER
- [ ] Add OPENAI_ASSISTANT_ID_TRANSLATOR
- [ ] Add OPENAI_VECTOR_STORE_ID_TRANSLATOR
- [ ] Add SUPABASE_URL
- [ ] Add SUPABASE_KEY
- [ ] Add BEARER_KEY (strong random value)
- [ ] Add REALM_ID=researcher (or translator)
- [ ] Add REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json
- [ ] Verify: All 8+ env vars are set (no missing)

### Deployment
- [ ] Push code to GitHub (or connect repo)
- [ ] Render auto-deploys on push
- [ ] Wait for build to complete
- [ ] Verify: Render logs show "Started for realm: researcher"
- [ ] Test endpoint:
  ```bash
  curl https://<your-render-service>.onrender.com/health
  # Should return 200 with realm_id
  ```

### Post-Deployment Tests
- [ ] Researcher recall endpoint works:
  ```bash
  curl https://<your-render-service>.onrender.com/researcher/recall \
    -H "Authorization: Bearer $BEARER_KEY" \
    -d '{"query": "test"}'
  ```
- [ ] Frontend can connect to Render backend
- [ ] Chat works end-to-end
- [ ] Data is saved to Supabase (research_sessions, etc.)
- [ ] Logs show "realm: researcher" (realm isolation)

---

## Phase 10: Acceptance & Validation ✅

### Functional Tests
- [ ] ✅ Researcher realm assistant is separate from Translator
- [ ] ✅ Research recall returns only research data
- [ ] ✅ Translation data is isolated in translations table
- [ ] ✅ Pronunciation cache is populated
- [ ] ✅ No cross-realm data leaks

### Performance Tests
- [ ] ✅ Recall latency < 500ms (adjust vector_store strategy if slower)
- [ ] ✅ Chat response time < 3 seconds (with recall)
- [ ] ✅ No timeout errors in logs

### Security Tests
- [ ] ✅ Bearer token required for endpoints
- [ ] ✅ Invalid realm_id returns 404
- [ ] ✅ Realm without recall enabled returns 403
- [ ] ✅ Supabase rows are filtered by realm_id (no leaks)

### Documentation Tests
- [ ] ✅ IMPLEMENTATION_ROADMAP.md is accurate
- [ ] ✅ ENV_SETUP_GUIDE.md covers all variables needed
- [ ] ✅ REALM_BLUEPRINT.md reflects actual implementation

---

## Optional Enhancements (Post-MVP)

- [ ] Add multi-realm UI selector (switch between researcher/translator)
- [ ] Add Supabase pgvector for cross-realm analytics
- [ ] Add pronunciation audio caching (S3 + CloudFront)
- [ ] Add realm health monitoring dashboard
- [ ] Add OpenAI token usage metrics per realm
- [ ] Add audit logging (who called what when)
- [ ] Add data export per realm (researcher workpapers, translator logs)

---

## Troubleshooting Guide

| Issue | Fix |
|-------|-----|
| "Realm not found" | Check REALM_CONFIG_PATH points to correct JSON file |
| "Invalid OpenAI API key" | Verify OPENAI_API_KEY environment variable is set |
| "Supabase connection refused" | Check SUPABASE_URL and firewall (allow Render IP) |
| "Recall latency > 1s" | Reduce top_k, or switch to OpenAI vector store only |
| "Cross-realm data leak" | Add WHERE realm_id in all Supabase queries |
| "Bearer token missing" | Verify Authorization header in requests |
| "304 Not Modified" | Clear RealmConfigLoader cache if testing |

---

## Sign-Off

- [ ] All phases complete
- [ ] All acceptance tests pass
- [ ] Documentation updated
- [ ] Team review passed
- [ ] Ready for production

**Date Completed:** ____________________

**Reviewed By:** ____________________

---

## Next Steps

1. ✅ You have the blueprint
2. 👉 Send CODEX_REVIEW_PROMPT.md to Codex
3. 🔨 Follow this checklist to implement
4. ✨ Deploy to Render
5. 🎉 Celebrate!

Questions? Refer to:
- REALM_BLUEPRINT.md (why)
- IMPLEMENTATION_EXAMPLES.md (how)
- ARCHITECTURE_DIAGRAMS.md (visual)
- ENV_SETUP_GUIDE.md (config)
- IMPLEMENTATION_ROADMAP.md (progress)
