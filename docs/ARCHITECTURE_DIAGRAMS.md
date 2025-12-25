# Architecture Diagram: Realm-Scoped Isolation

## Current State (Cross-Contaminated)
```
┌──────────────────────────────────────────────────────────────┐
│                        Frontend (React)                       │
│  ResearchPanel.jsx  TranslationPanel.jsx   ChatPanel.jsx     │
│  ↓                  ↓                       ↓                 │
│  All call: /vector/search, /kitenga/ask, /reo/translate     │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
        ┌────────────────────┐
        │  Proxy (8100)      │
        │  (FastAPI)         │
        └────────┬───────────┘
                 │
                 ▼
        ┌────────────────────┐
        │  Backend (8000)    │
        │  (Render)          │
        │                    │
        │  Routes:           │
        │  - /vector/search  │
        │  - /kitenga/ask    │
        │  - /reo/translate  │
        │  - /research/*     │
        │                    │
        │  (No realm scoping)│
        └────────┬───────────┘
                 │
            ┌────┴────────────────────┬──────────┐
            ▼                         ▼          ▼
        ┌────────┐              ┌──────────┐  ┌──────────┐
        │OpenAI  │              │Supabase  │  │Supabase  │
        │(Shared │              │(Shared   │  │(Shared   │
        │ vector │              │documents)│  │memory)   │
        │ store) │              └──────────┘  └──────────┘
        └────────┘
        
        ❌ PROBLEM: All realms share same vector store
           Research data mixed with translations
```

---

## Target State (Realm-Isolated)
```
┌──────────────────────────────────────────────────────────────┐
│                        Frontend (React)                       │
│                                                              │
│  ┌───────────────────┐     ┌──────────────────────────┐     │
│  │ResearchPanel.jsx  │     │TranslationPanel.jsx      │     │
│  │ realm_id=researcher     │ realm_id=translator      │     │
│  └────────┬──────────┘     └────────┬─────────────────┘     │
│           │                         │                       │
│           ├─→ POST /researcher/     │                       │
│           │    recall               │                       │
│           │    + /kitenga/ask       │                       │
│           │    + /research/stacked  │                       │
│           │                         │                       │
│           │                         ├─→ POST /translator/   │
│           │                         │    recall             │
│           │                         │    + /reo/translate   │
│           │                         │    + /reo/pronounce   │
│           │                         │                       │
│  (All calls prefixed by realm_id)  │                       │
└───────────┼─────────────────────────┼───────────────────────┘
            │                         │
            ▼                         ▼
        ┌────────────────────┐
        │  Proxy (8100)      │
        │  (FastAPI)         │
        └────────┬───────────┘
                 │
                 ▼
        ┌────────────────────┐
        │  Backend (8000)    │
        │  (Render)          │
        │                    │
        │  Routes:           │
        │  - /{realm}/recall │ ← NEW GATEWAY
        │  - /reo/translate  │ (unchanged)
        │  - /kitenga/ask    │ (unchanged)
        │  - /research/*     │ (unchanged)
        │                    │
        │  RealmConfigLoader │ ← NEW: Load configs
        │  RecallService     │ ← NEW: Search vectors
        └────────┬───────────┘
                 │
      ┌──────────┼──────────┐
      ▼          ▼          ▼
   ┌─────────────────────┐  ┌──────────────────────────┐
   │   OpenAI (scoped)   │  │   Supabase (scoped)      │
   │                     │  │                          │
   │ Researcher realm:   │  │ Researcher tables:       │
   │ - asst_researcher_x │  │ - research_sessions      │
   │ - vs_researcher_x   │  │ - research_notes         │
   │                     │  │ - research_chunks        │
   │ Translator realm:   │  │ - research_embeddings    │
   │ - asst_translator_y │  │                          │
   │ - vs_translator_y   │  │ Translator tables:       │
   └─────────────────────┘  │ - translations           │
                            │ - translation_logs       │
                            │ - pronunciation_cache    │
                            │                          │
                            │ All with realm_id filter │
                            └──────────────────────────┘

✅ SOLUTION: Each realm has isolated vectors, configs, tables
   Research data ≠ Translation data
```

---

## Data Flow: Researcher Realm
```
User: "Tell me about kōrero tīpuna"
  ↓
┌──────────────────────────────────────────────────────┐
│  ChatPanel.jsx                                       │
│  realm_id = "researcher"                             │
│  Calls: POST /researcher/recall                      │
└──────────────────┬───────────────────────────────────┘
                   │
         ┌─────────┴──────────┐
         ▼                    ▼
    ┌────────────┐      ┌──────────────┐
    │   Proxy    │      │   Recall     │
    │            │──→   │   Gateway    │
    │ 8100       │      │  (backend)   │
    └────────────┘      └──────┬───────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
              ┌──────────────┐      ┌──────────────┐
              │ OpenAI       │      │ Supabase     │
              │ Vector Store │      │ pgvector     │
              │              │      │              │
              │ Search with: │      │ Search with: │
              │ vs_researchr │      │ realm_id=    │
              │              │      │ "researcher" │
              └────────┬─────┘      └────┬─────────┘
                       │                 │
                       └────────┬────────┘
                                ▼
                    ┌───────────────────────┐
                    │   Recall Results      │
                    │                       │
                    │ [                     │
                    │  {                    │
                    │    "id": "chunk_1",   │
                    │    "source": "doc_1", │
                    │    "score": 0.92,     │
                    │    "snippet": "..."   │
                    │  },                   │
                    │  ...                  │
                    │ ]                     │
                    └───────────┬───────────┘
                                │
                    ┌───────────┴────────────┐
                    ▼                        ▼
            ┌──────────────┐         ┌──────────────┐
            │ Compose      │         │  Assistant   │
            │ Context      │    +    │ (thread_id)  │
            └──────┬───────┘         └──────┬───────┘
                   │                        │
                   └────────────┬───────────┘
                                ▼
                    ┌───────────────────────┐
                    │  OpenAI Assistant     │
                    │  Runs with context    │
                    └────────────┬──────────┘
                                 │
                    ┌────────────┴──────────┐
                    ▼                       ▼
            ┌──────────────┐         ┌──────────────┐
            │ Chat UI      │         │  Save to     │
            │ Streams      │         │  research_   │
            │ Response     │         │  notes table │
            └──────────────┘         └──────────────┘
```

---

## Data Flow: Translator Realm
```
User: "Translate 'hello' to Te Reo"
  ↓
┌──────────────────────────────────────┐
│  TranslationPanel.jsx                │
│  realm_id = "translator"             │
│  Calls: POST /reo/translate          │
└──────────────┬──────────────────────┘
               │
      ┌────────┴─────────┐
      ▼                  ▼
  ┌────────┐         ┌──────────────────┐
  │ Proxy  │──→      │  Backend Route   │
  │ 8100   │         │  /reo/translate  │
  └────────┘         └──────┬───────────┘
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
              ┌──────────┐     ┌──────────────┐
              │ OpenAI   │     │ Supabase     │
              │ GPT-4    │     │ tables:      │
              │ (scoped  │     │ - trans-     │
              │ to       │     │   lations    │
              │ asst_    │     │ - trans-     │
              │ translator)    │   lation_    │
              │          │     │   logs       │
              └──────┬───┘     │ - pronun-    │
                     │         │   ciation_   │
                     │         │   cache      │
                     │         │              │
                     │         │ (all with    │
                     │         │  realm_id=   │
                     │         │  translator) │
                     │         └────┬─────────┘
                     │              │
                     └──────┬───────┘
                            ▼
          ┌─────────────────────────────┐
          │ Translation Result:         │
          │ {                           │
          │   "output": "Kia ora",      │
          │   "confidence": 0.95,       │
          │   "dialect": "northland"    │
          │ }                           │
          └──────────┬──────────────────┘
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
    ┌──────────┐         ┌──────────────┐
    │ Chat UI  │         │  Save to     │
    │ Shows    │         │  trans-      │
    │ "Kia ora"│         │  lations &   │
    └──────────┘         │  trans-      │
                         │  lation_logs │
                         │  (with realm │
                         │   = translator)
                         └──────────────┘
```

---

## Configuration Structure
```
mauri/
  realm_manifest.json (global, minimal - backward compat)
  realms/
    researcher/
      manifest.json ← Load this for researcher realm
      {
        "realm_id": "researcher",
        "openai": {
          "assistant_id": "asst_researcher_xxxxx",
          "vector_store_id": "vs_researcher_xxxxx"
        },
        "features": { "recall": true, ... }
      }
    translator/
      manifest.json ← Load this for translator realm
      {
        "realm_id": "translator",
        "openai": {
          "assistant_id": "asst_translator_yyyyy",
          "vector_store_id": "vs_translator_yyyyy"
        },
        "features": { "recall": false, ... }
      }
```

---

## Database Isolation
```
┌───────────────────────────────────────┐
│        Supabase (Single Instance)     │
├───────────────────────────────────────┤
│                                       │
│  Researcher Realm Tables:             │
│  ┌─────────────────────────────┐     │
│  │ research_sessions           │     │
│  │ id | realm_id | thread_id.. │     │
│  │    | researcher             │     │
│  └─────────────────────────────┘     │
│  ┌─────────────────────────────┐     │
│  │ research_notes              │     │
│  │ id | realm_id | content...  │     │
│  │    | researcher             │     │
│  └─────────────────────────────┘     │
│                                       │
│  Translator Realm Tables:             │
│  ┌─────────────────────────────┐     │
│  │ translations                │     │
│  │ id | realm_id | source_text │     │
│  │    | translator             │     │
│  └─────────────────────────────┘     │
│  ┌─────────────────────────────┐     │
│  │ translation_logs            │     │
│  │ id | realm_id | latency_ms. │     │
│  │    | translator             │     │
│  └─────────────────────────────┘     │
│  ┌─────────────────────────────┐     │
│  │ pronunciation_cache         │     │
│  │ id | realm_id | text...     │     │
│  │    | translator             │     │
│  └─────────────────────────────┘     │
│                                       │
│  QUERIES (realm-isolated):            │
│  WHERE realm_id = 'researcher'  ✅    │
│  WHERE realm_id = 'translator'  ✅    │
│  (no WHERE realm_id)            ❌    │
│                                       │
└───────────────────────────────────────┘
```

---

## Deployment Architecture
```
┌─────────────────────────────────────────────────────────┐
│               Render (Production)                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Service 1: Researcher Realm                          │
│  ┌──────────────────────────────────────────────┐    │
│  │ ENV: REALM_ID=researcher                     │    │
│  │ ENV: OPENAI_ASSISTANT_ID_RESEARCHER=asst_x  │    │
│  │ ENV: OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_x │    │
│  │                                              │    │
│  │ Backend Python App                           │    │
│  │ - Load realm config                          │    │
│  │ - Expose /researcher/recall                  │    │
│  │ - Connect to Supabase (filtered by realm_id) │    │
│  └──────────────────────────────────────────────┘    │
│  URL: https://aotahi-researcher.onrender.com         │
│                                                         │
│  Service 2: Translator Realm (Optional)              │
│  ┌──────────────────────────────────────────────┐    │
│  │ ENV: REALM_ID=translator                     │    │
│  │ ENV: OPENAI_ASSISTANT_ID_TRANSLATOR=asst_y  │    │
│  │ ENV: OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_y │    │
│  │                                              │    │
│  │ Backend Python App                           │    │
│  │ - Load realm config                          │    │
│  │ - Expose /translator/recall                  │    │
│  │ - Connect to Supabase (filtered by realm_id) │    │
│  └──────────────────────────────────────────────┘    │
│  URL: https://aotahi-translator.onrender.com         │
│                                                         │
│  ┌──────────────────────────────────────────────┐    │
│  │ Shared Supabase Database                     │    │
│  │ (both services read/write with realm_id)    │    │
│  └──────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Summary

**Key Benefits:**

1. **No Cross-Contamination** — Each realm has isolated OpenAI Assistant, Vector Store, Supabase tables
2. **Centralized Recall** — Single `/{realm_id}/recall` endpoint replaces scattered search calls
3. **Scalable** — Add new realms by creating new configs + tables (no code changes)
4. **Observable** — Realm-scoped logs in Supabase for analytics
5. **Cost-Aware** — Choose vector store (OpenAI, Supabase, or both) per realm

**Next Step:** Send `CODEX_REVIEW_PROMPT.md` to Codex for code mapping & patches.
