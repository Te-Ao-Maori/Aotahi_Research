# Realm Blueprint: Clean Separation & Cross-Contamination Prevention

## Overview

This blueprint locks in the architecture for **Researcher** and **Translator** realms to prevent cross-contamination between cards. Each realm gets its own OpenAI Assistant, Vector Store, and Supabase tables.

---

## 1. Realm Configuration Structure

### Current State
- `mauri/realm_manifest.json` is global, minimal
- No per-realm Assistant or Vector Store IDs
- Frontend hardcodes paths like `/reo/translate`, `/research/stacked`, `/vector/search`

### Target State
Each realm (e.g., `researcher`, `translator`) gets a config block:

```json
{
  "realm_id": "researcher",
  "display_name": "Māori Research Realm",
  "te_po_url": "http://localhost:5000",
  "auth_mode": "bearer",
  "openai": {
    "assistant_id": "asst_researcher_xxxxx",
    "vector_store_id": "vs_researcher_xxxxx"
  },
  "supabase": {
    "project_url": "https://xxxx.supabase.co",
    "anon_key": "eyXxxx"
  },
  "features": {
    "vector_search": true,
    "pipeline": true,
    "recall": true
  },
  "created_at": "2025-12-16T00:00:00Z",
  "version": "1.0.0"
}
```

**Decision:** Store in `mauri/realms/{realm_id}/manifest.json` to allow multi-realm deployments without collision.

---

## 2. Supabase Schema (Minimum Set)

### Researcher Realm Tables

#### `research_sessions` (thread/session metadata)
```sql
CREATE TABLE research_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  thread_id TEXT NOT NULL UNIQUE, -- OpenAI Assistant thread
  assistant_id TEXT NOT NULL,
  vector_store_id TEXT NOT NULL,
  title TEXT,
  status TEXT DEFAULT 'active', -- active, archived, draft
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  INDEX(realm_id, user_id),
  INDEX(thread_id)
);
```

#### `research_notes` (summaries, citations, links)
```sql
CREATE TABLE research_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES research_sessions(id),
  realm_id TEXT NOT NULL,
  note_type TEXT, -- 'summary', 'citation', 'link', 'insight'
  content TEXT NOT NULL,
  source_url TEXT,
  confidence FLOAT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  INDEX(session_id),
  INDEX(realm_id)
);
```

#### `research_chunks` (optional — if chunking before embedding)
```sql
CREATE TABLE research_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  source_id TEXT, -- document or URL
  chunk_index INT,
  content TEXT NOT NULL,
  embedding VECTOR(1536), -- pgvector
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  INDEX(realm_id),
  INDEX(source_id)
);
```

### Translator Realm Tables

#### `translations` (source_text, target_text, dialect, model, confidence)
```sql
CREATE TABLE translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  source_text TEXT NOT NULL,
  target_text TEXT NOT NULL,
  source_lang TEXT, -- 'en', 'mi' (te reo)
  target_lang TEXT,
  dialect TEXT, -- 'northland', 'waikato', etc. (optional)
  model TEXT, -- 'gpt-4', 'gpt-3.5', 'custom'
  confidence FLOAT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  INDEX(realm_id, user_id),
  INDEX(source_text)
);
```

#### `translation_logs` (request/response metadata + timing)
```sql
CREATE TABLE translation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  translation_id UUID REFERENCES translations(id),
  request_tokens INT,
  response_tokens INT,
  latency_ms INT,
  status TEXT, -- 'success', 'error', 'timeout'
  error_message TEXT,
  created_at TIMESTAMP DEFAULT now(),
  INDEX(realm_id),
  INDEX(translation_id)
);
```

#### `pronunciation_cache` (phonetics/audio hints)
```sql
CREATE TABLE pronunciation_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  text TEXT NOT NULL UNIQUE,
  ipa_phonetic TEXT,
  audio_url TEXT, -- S3 or CDN URL
  confidence FLOAT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  INDEX(realm_id, text)
);
```

**Key Principle:** All tables have `realm_id` column. This ensures multi-realm isolation at the database level.

---

## 3. Dual-Vector Strategy (OpenAI + Supabase)

### Where Each Vector Store Shines

| Use Case | OpenAI Vector Store | Supabase pgvector |
|----------|---------------------|-------------------|
| **Fast assistant retrieval** | ✅ Native to runs | — |
| **Cross-realm search** | — | ✅ Query across realms |
| **Ownership/lineage** | — | ✅ Track source + metadata |
| **Cost optimization** | Fast (embedded) | Query-based (pay per call) |
| **Multi-modal** | Limited | Can index multiple formats |

### Practical Rule: Write Once, Store Twice (Conditionally)

```
Input: Document chunk
  ↓
1. Embed (OpenAI Embeddings API or local model)
  ├─ Store embedding + chunk → OpenAI Vector Store (for assistant retrieval)
  └─ Store embedding + chunk → Supabase pgvector (for analytics + app-wide search)
  ↓
Output: Indexed in both places
```

**Cost Decision Tree:**
- **Cost matters? Start with OpenAI Vector Store only.**
  - Add Supabase embeddings after recall is stable & you need analytics.
- **Need analytics/multi-realm search now?**
  - Use both from day one.
- **Migrating existing embeddings?**
  - Bulk-load Supabase from OpenAI vector store export.

---

## 4. Recall Wiring (Single Gateway per Realm)

### Backend Recall Endpoint Structure

```
POST /{realm_id}/recall
Content-Type: application/json

Request:
{
  "query": "kōrero about traditional fishing",
  "thread_id": "thread_abc123", -- optional, for session context
  "top_k": 5,
  "vector_store": "openai" -- or "supabase" or "both"
}

Response:
{
  "matches": [
    {
      "id": "chunk_uuid",
      "source": "document_title or URL",
      "score": 0.92,
      "snippet": "...",
      "metadata": { "page": 3, "realm_id": "researcher", ... }
    },
    ...
  ],
  "query_tokens": 12,
  "recall_latency_ms": 145
}
```

### Implementation Checklist

1. **Route:** `POST /researcher/recall` and `POST /translator/recall`
2. **Load realm config** from `mauri/realms/{realm_id}/manifest.json`
3. **Embed query** using OpenAI Embeddings API
4. **Search OpenAI vector store** if requested
5. **Search Supabase pgvector** if requested
6. **Merge & rank** results by score
7. **Log query + results** to Supabase (for analytics)
8. **Return** matches with source + score + snippet

### Where Recall Fits in Chat Pipeline

```
User message
  ↓
Recall (via /{realm_id}/recall)
  ↓
Compose context (system prompt + recalled chunks)
  ↓
Call OpenAI Assistant with thread_id
  ↓
Stream response back to chat UI
  ↓
Save result + citations to Supabase (research_notes or translations)
```

---

## 5. Current Endpoints Being Called (By Realm)

### Researcher Realm
- `POST /research/stacked` – Multi-step research pipeline
- `POST /vector/search` – Vector search (needs recall gateway)
- `POST /kitenga/ask` – OpenAI Assistant chat
- `POST /kitenga/gpt-whisper` – Streaming chat with pipeline
- `POST /chat/save-session` – Save conversation
- `GET /documents/profiles` – List recent documents

### Translator Realm
- `POST /reo/translate` – Te Reo ↔ English translation
- `POST /reo/explain` – Explain meaning
- `POST /reo/pronounce` – Audio pronunciation

### Shared/Admin
- `GET /health` – Health check
- `GET /status/full` – Full status

**Action:** These routes should NOT change. Instead, add `/{realm_id}/recall` and namespace tables.

---

## 6. File & Code Changes (Minimum Patch Set)

### Backend (te_po or main backend)

#### New File: `routes/recall.py`
Implements the `/{realm_id}/recall` gateway endpoint.

#### New File: `schema/realms.py`
Loads realm config from `mauri/realms/{realm_id}/manifest.json`.

#### Modify: `db/supabase.py` (if exists) or `utils/db.py`
Add realm_id parameter to all queries.

#### Modify: `.env.example`
Add realm config paths:
```
REALM_ID=researcher
REALM_CONFIG_PATH=mauri/realms/${REALM_ID}/manifest.json
OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx
OPENAI_ASSISTANT_ID_TRANSLATOR=asst_yyyyy
OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_yyyyy
```

### Frontend (te_ao)

#### Modify: `src/hooks/useApi.js`
Support per-realm base URL (already hardcoded to TE_PO_BASE_URL, so no change needed).

#### Modify: `src/panels/ChatPanel.jsx`
When recalling, call `/{realm_id}/recall` instead of scattered `/vector/search` calls.

#### Modify: `src/panels/ResearchPanel.tsx`
Same — use centralized recall gateway.

#### Modify: `src/panels/TranslatePanel.jsx`
Already isolated; ensure translation logs are sent to `translations` + `translation_logs` tables.

### Database (Supabase)

#### Create Tables
Run migration scripts to create researcher & translator tables (schema provided above).

#### Update RLS Policies
Ensure `realm_id` is part of every row-level security policy.

---

## 7. Environment & Deployment

### Local Development

```bash
# Start with Researcher realm
export REALM_ID=researcher
export REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json
export OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx
export OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx

# Or Translator realm
export REALM_ID=translator
export REALM_CONFIG_PATH=mauri/realms/translator/manifest.json
export OPENAI_ASSISTANT_ID_TRANSLATOR=asst_yyyyy
export OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_yyyyy

python -m uvicorn main:app --reload
```

### Render Deployment (Production)

Add to Render environment:
```
REALM_ID=researcher
REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json
OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx
```

---

## 8. Validation Checklist

- [ ] Realm config file exists: `mauri/realms/{realm_id}/manifest.json`
- [ ] OpenAI Assistant ID scoped to realm (environment variable)
- [ ] OpenAI Vector Store ID scoped to realm (environment variable)
- [ ] Supabase tables created with `realm_id` column
- [ ] `/{realm_id}/recall` endpoint implemented and tested
- [ ] Chat pipeline calls recall gateway, not scattered `/vector/search`
- [ ] Translation logs saved to `translations` + `translation_logs` tables
- [ ] Pronunciation cache stored in dedicated table with realm_id
- [ ] Proxy (`te_po_proxy`) passes `REALM_ID` to backend
- [ ] Frontend never hardcodes realm ID (uses config)
- [ ] No cross-realm data leaks in Supabase queries (always filter by realm_id)

---

## Summary

This blueprint ensures:
1. **No cross-contamination** — Each realm is isolated by ID at schema level.
2. **Scalable** — Add new realms by creating new configs + tables.
3. **Focused recall** — Single `/{realm_id}/recall` endpoint instead of scattered search calls.
4. **Cost-aware** — Dual-vector strategy gives you flexibility (OpenAI-only vs. dual).
5. **Observable** — Realm-scoped logs in Supabase for analytics.

Ready for Codex review. 🎯
