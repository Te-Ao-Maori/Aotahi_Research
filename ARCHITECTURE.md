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
┌─ te_po_proxy (FastAPI) ─────────────────────────────────────┐
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
┌─ te_po_proxy ───────────────────────────────────────────────┐
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
- **8000**: te_po_proxy (FastAPI proxy server)
- **5000**: Your main Te Pó backend (should be running separately)

All three should be running for full functionality.
