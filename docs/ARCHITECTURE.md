# Architecture & Connection Flow

## Request Flow Example: User Clicks "Translate"

```
┌─ Frontend (React) ──────────────────────────────────────────┐
│                                                              │
│  User types: "Kia ora"                                      │
│  Clicks: [Translate]                                        │
│                                                              │
│  ChatPanel.jsx calls:                                       │
│    callApi("/reo/translate", {                              │
│      method: "POST",                                        │
│      body: { text: "Kia ora" }                              │
│    })                                                       │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP POST
                           │ http://localhost:8000/reo/translate
                           │ Body: {"text": "Kia ora"}
                           │ Header: Authorization: Bearer <token>
                           ▼
┌─ te_po proxy (FastAPI) ─────────────────────────────────────┐
│                                                              │
│  Receives POST /reo/translate                               │
│                                                              │
│  proxy() function:                                          │
│    1. Builds upstream_url = TE_PO_URL + /reo/translate      │
│    2. Copies headers from frontend request                  │
│    3. Adds Bearer token if configured                       │
│    4. Reads request body                                    │
│    5. Forwards to backend via httpx                         │
│                                                              │
│  TE_PO_URL = http://localhost:5000 (from .env)              │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP POST
                           │ http://localhost:5000/reo/translate
                           │ Body: {"text": "Kia ora"}
                           │ Header: Authorization: Bearer <token>
                           ▼
┌─ Main Te Pó Backend ─────────────────────────────────────────┐
│                                                              │
│  Receives POST /reo/translate                               │
│                                                              │
│  Backend processes:                                         │
│    1. Validates Bearer token                                │
│    2. Calls GPT-4 or translation service                    │
│    3. Returns: {"output": "Hello"}                          │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP 200 OK
                           │ Body: {"output": "Hello"}
                           ▼
┌─ te_po proxy ───────────────────────────────────────────────┐
│                                                              │
│  Response handler:                                          │
│    1. Gets response from backend                            │
│    2. Preserves status code, headers, body                  │
│    3. Sends to frontend                                     │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP 200 OK
                           │ Body: {"output": "Hello"}
                           ▼
┌─ Frontend (React) ──────────────────────────────────────────┐
│                                                              │
│  ChatPanel receives response:                               │
│    result = {output: "Hello"}                               │
│                                                              │
│  Updates UI:                                                │
│    Shows: "Hello" in chat panel                             │
│    Adds entry to responses list                             │
│                                                              │
│  User sees result ✓                                         │
│                                                              │
└────────────────────────────────────────────────────────────┘
```

## All Endpoints Being Called

The frontend ChatPanel.jsx makes these API calls:

### Status & Info
- `GET /status/full` - Check OpenAI, Supabase, Vector DB status
- `GET /health` - Proxy health check
- `GET /documents/profiles?limit=10` - Recent documents

### Chat & Reasoning
- `POST /kitenga/ask` - OpenAI Assistant chat
- `POST /kitenga/gpt-whisper` - Main chat with pipeline
- `POST /chat/save-session` - Save conversation

### Reo (Language) Operations
- `POST /reo/translate` - Te Reo ↔ English
- `POST /reo/explain` - Explain meaning
- `POST /reo/pronounce` - Audio pronunciation

### Search & Retrieval
- `POST /vector/search` - Semantic search
- `POST /research/stacked` - Web + Vector search

### File Upload & Processing
- `POST /intake/ocr` - Image to text (OpenAI Vision)

## Environment Variables Summary

```
Frontend (te_ao/.env):
  VITE_API_URL=http://localhost:8000  ← Points to proxy

Proxy (root .env):
  TE_PO_URL=http://localhost:5000     ← Points to your backend
  BEARER_KEY=test-token              ← Forwarded in Auth header
  REALM_ID=maori_research             ← For identification
  PROXY_PORT=8000                     ← Proxy listens on this

Backend (.env or config):
  Should handle Bearer token validation
  Should have OpenAI, Supabase, Vector DB configured
```

## Network Ports

- **5173**: Frontend React dev server (npm run dev)
- **8000**: te_po proxy (FastAPI proxy server)
- **5000**: Your main Te Pó backend (should be running separately)

All three should be running for full functionality.

## Deployment & Hosting Strategy

- **Render-hosted frontend/proxy**: The goal is to keep this repo lightweight—`te_ao/` and its proxy (`te_po/proxy`) act as a standalone UI surface that routes all heavy work back to the AwaNet/Te Pó stack on Render (via `TE_PO_URL`). This keeps deployment simple while letting Render handle the GPT, Supabase, and recall services.
- **Render for backend calls**: Any request that needs the main Te Pó capabilities (chat pipelines, translations, Supabase access) should pass through the proxy to the Render service rather than duplicating logic here. That makes it safe to serve te_ao as a static app while staying in sync with the existing backend.
- **Cloudflare / git automation**: When you’re ready to publish, a `git push` (or CI pipeline) can build the frontend assets, run the proxy/backend tests, and publish to Cloudflare Pages or Workers. Confirm everything passes locally (proxy on 8100, backend on 8000, frontend on 5000) before shipping the Cloudflare deploy to keep rollouts predictable.

## GPT Tool Manifest

- **Expose `.well-known/kitenga.json`** (or similar) from the proxy/backend so GPT builders can auto-discover your tool schema. Document the manifest URL in your GPT toolkit setup and make sure `api_spec_url` and `api_url` point at the Render deployment. That way Kitenga Whiro on the GPT platform can call the same endpoints the frontend uses.
- **Keep the GPT surface minimal**: Only expose the endpoints GPT needs (e.g., `/reo/translate`, `/kitenga/gpt-whisper`, `/research/stacked`) and rely on Render for auth/supabase/assistant state. This mirrors how the frontend already interacts with the proxy.
