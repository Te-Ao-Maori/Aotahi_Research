# Cross-Contamination Prevention: Implementation Roadmap

**Status:** Blueprint locked. Ready for Codex review.

**Objective:** Clean separation of Researcher and Translator realms to prevent data/config cross-contamination.

---

## What's Been Created

### 1. **REALM_BLUEPRINT.md**
The architectural blueprint that defines:
- Realm configuration structure (per-realm manifests)
- Supabase schema (research_sessions, translations, pronunciation_cache, etc.)
- Dual-vector strategy (OpenAI + Supabase)
- Recall gateway endpoint (`POST /{realm_id}/recall`)
- Chat pipeline integration
- Validation checklist

**Use Case:** Reference document for understanding the full design.

### 2. **CODEX_REVIEW_PROMPT.md**
A detailed prompt to send to Codex that:
- Explains the constraints (don't refactor unrelated code)
- Lists current endpoints and API calls
- Asks Codex to map existing routes and propose minimum patches
- Specifies output format (file list + exact diffs)
- Includes acceptance criteria

**Use Case:** Copy-paste this into Codex to get a focused code review.

### 3. **IMPLEMENTATION_EXAMPLES.md**
Code patterns showing:
- `RealmConfigLoader` — Load realm configs from JSON
- `RecallService` — Embed query, search vectors, merge results
- `recall()` endpoint — FastAPI route for `POST /{realm_id}/recall`
- Integration example — How to modify ChatPanel.jsx
- Notes on pgvector function, error handling, testing

**Use Case:** Reference for developers implementing the changes.

### 4. **ENV_SETUP_GUIDE.md**
Environment variables guide:
- Local `.env` template for researcher/translator realms
- Render production setup
- How to get OpenAI, Supabase, AWS credentials
- Validation checklist
- Multi-realm production setup
- Troubleshooting

**Use Case:** Configuration reference for deployment.

### 5. **Database Migration**
SQL file: `migrations/001_realm_tables.sql`

Creates tables:
- **Researcher:** research_sessions, research_notes, research_chunks, research_embeddings
- **Translator:** translations, translation_logs, pronunciation_cache

All with `realm_id` column for isolation.

**Use Case:** Run this migration on Supabase to set up the schema.

### 6. **Realm Config Files (Examples)**
- `mauri/realms/researcher/manifest.json`
- `mauri/realms/translator/manifest.json`

Each contains:
- realm_id, display_name
- OpenAI assistant_id, vector_store_id
- Supabase project URL, anon_key
- Feature flags (vector_search, recall, memory, etc.)

**Use Case:** Templates to fill in with actual IDs.

---

## Next Steps: Codex Review

### Step 1: Send Codex the Prompt
Copy the entire **CODEX_REVIEW_PROMPT.md** and send it to Codex. Ask it to:
1. Scan the repo and identify existing routes
2. Map where vector search / recall is currently implemented
3. Propose the minimum file changes needed
4. Output exact file list + code diffs

### Step 2: Review Codex Output
When Codex returns its analysis:
1. Verify file mappings are correct (check actual files)
2. Review proposed diffs for correctness
3. Ask clarifying questions if anything is unclear
4. Request Codex to adjust if needed

### Step 3: Apply Changes
Once you're confident in Codex's output:
1. Apply diffs to backend code (recall.py, realms.py, etc.)
2. Run Supabase migration SQL
3. Fill in realm configs with actual IDs from OpenAI
4. Set environment variables locally
5. Test the recall endpoint
6. Update frontend ChatPanel.jsx to use `/{realm_id}/recall`
7. Deploy to Render

---

## Key Architectural Decisions

### 1. **Realm Isolation**
- Each realm has separate OpenAI Assistant + Vector Store IDs
- Config stored in `mauri/realms/{realm_id}/manifest.json`
- All Supabase tables have `realm_id` column
- **Result:** No cross-contamination; can spin up new realms anytime

### 2. **Recall Gateway**
- Single endpoint: `POST /{realm_id}/recall`
- Replaces scattered `/vector/search` calls
- Supports OpenAI vector store, Supabase pgvector, or both
- Returns standardized format: matches + metadata
- **Result:** Cleaner chat pipeline, easier to test/monitor

### 3. **Dual-Vector Strategy**
- **OpenAI vector store:** Best for fast assistant retrieval (native to runs)
- **Supabase pgvector:** Best for analytics, cross-realm search, data ownership
- **Cost rule:** Start with OpenAI only, add Supabase after recall is stable
- **Result:** Flexibility; scale vector storage without major rewrites

### 4. **Database Schema**
- Researcher tables: sessions, notes, chunks, embeddings
- Translator tables: translations, logs, pronunciation_cache
- All realm-scoped with proper indexes
- **Result:** Clear data separation; easy to query per-realm

---

## Validation & Testing

### Local Testing (Before Render Deployment)
```bash
# 1. Load realm config
curl http://localhost:8000/health

# 2. Test recall endpoint
curl -X POST http://localhost:8000/researcher/recall \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{
    "query": "kōrero about fishing",
    "thread_id": "thread_123",
    "top_k": 5,
    "vector_store": "openai"
  }'

# 3. Verify realm isolation (data should be different for each realm)
curl -X GET https://xxxx.supabase.co/rest/v1/research_sessions?realm_id=eq.researcher \
  -H "Authorization: Bearer $SUPABASE_KEY"

curl -X GET https://xxxx.supabase.co/rest/v1/translations?realm_id=eq.translator \
  -H "Authorization: Bearer $SUPABASE_KEY"

# 4. Test chat pipeline with recall
# Send message in ChatPanel, verify recall is called
```

### Acceptance Criteria
- [ ] Realm configs load correctly from `mauri/realms/{realm_id}/manifest.json`
- [ ] `POST /{realm_id}/recall` endpoint returns matches with score + snippet
- [ ] Researcher realm only shows research_sessions, not translations
- [ ] Translator realm only shows translations, not research_sessions
- [ ] No cross-realm data leaks (queries always filter by realm_id)
- [ ] ChatPanel calls recall gateway, not scattered `/vector/search`
- [ ] Render deployment works with environment variables
- [ ] Multiple realms can coexist without collision

---

## File Checklist

**Already Created:**
- ✅ REALM_BLUEPRINT.md
- ✅ CODEX_REVIEW_PROMPT.md
- ✅ IMPLEMENTATION_EXAMPLES.md
- ✅ ENV_SETUP_GUIDE.md
- ✅ migrations/001_realm_tables.sql
- ✅ mauri/realms/researcher/manifest.json
- ✅ mauri/realms/translator/manifest.json

**To Be Created (by Codex):**
- schema/realms.py (RealmConfigLoader)
- utils/recall_service.py or routes/recall.py (RecallService + endpoint)
- Modified routes/main.py or similar (include recall router)
- Modified .env.example (realm variables)
- Modified src/panels/ChatPanel.jsx (use recall gateway)

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Existing routes break | Don't change `/reo/translate`, `/kitenga/ask`, etc. Only add new `/recall` endpoint |
| Cross-realm data leak | All Supabase queries filter by `realm_id`. RLS policies enforce it. |
| Vector store collision | Each realm gets separate OpenAI Vector Store ID. Isolated by design. |
| Deployment fails | ENV_SETUP_GUIDE covers all variables needed. Use .env.example as checklist. |
| Recall latency | Recall service can search OpenAI (fast) or Supabase (query-based). Start with OpenAI. |

---

## Timeline Estimate

**With Codex:**
1. Send prompt + get analysis: ~10 min
2. Review & clarify diffs: ~15 min
3. Apply diffs to code: ~20 min
4. Run Supabase migration: ~5 min
5. Fill in realm configs: ~5 min
6. Local testing: ~20 min
7. Deploy to Render: ~10 min

**Total: ~1.5 hours** (depending on backend code complexity)

---

## Success Criteria

✅ **You'll know it's working when:**

1. Researcher realm has its own Assistant + Vector Store (different from Translator)
2. Research data (sessions, notes) is isolated in researcher tables
3. Translation data is isolated in translator tables
4. `POST /{realm_id}/recall` returns matches for the correct realm only
5. ChatPanel successfully uses recall gateway instead of `/vector/search`
6. Render deployment uses environment-scoped variables (no hardcoded IDs)
7. No data cross-contamination between realms

---

## Questions or Blockers?

Before sending to Codex, clarify:

1. **Backend location:** Where is the main Te Pó backend code? (Render, local, GitHub?)
2. **Current routing:** Does the backend use FastAPI, Flask, or another framework?
3. **Supabase status:** Is migration already set up? Do you have admin access?
4. **OpenAI readiness:** Do you have API key + created assistants with Vector Stores?
5. **Frontend testing:** Can you locally run frontend + backend + proxy together?

---

## Summary

You now have a **complete, locked blueprint** for realm-scoped isolation:

- ✅ Architecture documented (REALM_BLUEPRINT.md)
- ✅ Code patterns provided (IMPLEMENTATION_EXAMPLES.md)
- ✅ Database schema ready (migrations/001_realm_tables.sql)
- ✅ Realm configs templated (mauri/realms/)
- ✅ Env variables documented (ENV_SETUP_GUIDE.md)
- ✅ Codex review prompt ready (CODEX_REVIEW_PROMPT.md)

**Next action:** Send CODEX_REVIEW_PROMPT.md to Codex for code mapping & minimum patch set.
