# 🔌 Frontend-to-Backend Connection Setup

## How It Works Now

```
Frontend (localhost:5173)
    ↓ HTTP calls to /reo/translate, /kitenga/ask, etc.
    ↓ (via VITE_API_URL)
Proxy (localhost:8000)
    ↓ Forwards all requests with Bearer token
    ↓ (via TE_PO_URL)
Your Main Te Pó Backend (localhost:5000 or remote)
```

## What Was Fixed

1. ✅ **Proxy now properly forwards ALL HTTP methods** (GET, POST, PUT, DELETE, PATCH)
2. ✅ **Proxy preserves request bodies** (JSON, form-data, multipart)
3. ✅ **Proxy preserves query strings** (e.g., `?limit=5`)
4. ✅ **Bearer token automatically injected** by proxy
5. ✅ **Better error logging** in proxy for debugging

## Configuration

### Step 1: Update `.env` with Your Backend URL

Edit [.env](.env) and set `TE_PO_URL` to your actual main Te Pó backend:

```dotenv
# If running locally on port 5000:
TE_PO_URL=http://localhost:5000

# If running on a remote server:
TE_PO_URL=https://my-te-po-backend.example.com

# Make sure BEARER_KEY matches what your backend expects
BEARER_KEY=your-api-token-here
```

### Step 2: Restart the Proxy

```bash
# Terminal 2 - Stop the old proxy (Ctrl+C) and restart:
python te_po_proxy/main.py
```

You should see:
```
[te_po_proxy] Started for realm: maori_research
[te_po_proxy] Upstream Te Pó: http://localhost:5000
```

### Step 3: Test the Connection

1. **Check proxy health:**
   ```bash
   curl http://localhost:8000/health
   ```
   Should return:
   ```json
   {"status":"ok","realm":"maori_research","upstream":"http://localhost:5000"}
   ```

2. **Trigger any button in the UI** (Summarize, Translate, Explain, etc.) and watch:
   - **Frontend Console** (F12) - Check for fetch errors
   - **Proxy Terminal** - You'll see log lines like:
     ```
     [te_po_proxy] Error proxying POST /reo/translate: Connection refused
     ```
     This tells you whether the proxy reached the backend

## What Each Button Does Now

| Button | Calls | Endpoint |
|--------|-------|----------|
| Summarize | GPT-4 via OpenAI assistant | `/kitenga/gpt-whisper` |
| Translate | Te Reo ↔ English | `/reo/translate` |
| Explain | Contextual explanation | `/reo/explain` |
| Pronounce | Audio pronunciation | `/reo/pronounce` |
| OCR | Vision API on image | `/intake/ocr` |
| Research | Vector + Web search | `/research/stacked` |
| Web Search | BraveSearch integration | (within `/research/stacked`) |
| Sync | Load recent docs | `/documents/profiles` |
| Recall | Vector search | `/vector/search` |
| Save Chat | Store session | `/chat/save-session` |

## Troubleshooting

### "Failed to fetch" error in browser

1. Check if proxy is running: `curl http://localhost:8000/health`
2. Check if backend is accessible: `curl http://localhost:5000/health`
3. Check browser console for CORS errors

### Proxy logs show "Connection refused"

- Verify `TE_PO_URL` in `.env` is correct
- Make sure your main Te Pó backend is running

### 502 Bad Gateway

- Backend didn't respond in time or crashed
- Check your main Te Pó backend logs

### "OpenAI down" message in UI

- Your backend couldn't reach OpenAI API
- This is a backend-side issue, not the proxy

## Frontend Environment Variables

In [te_ao/.env](te_ao/.env):
- `VITE_API_URL=http://localhost:8000` - Points to the proxy
- `VITE_PIPELINE_TOKEN` - Bearer token (already set in frontend hook)

These should work as-is with the proxy.

## Next Steps

1. Start your main Te Pó backend if not running
2. Restart the proxy with correct `TE_PO_URL`
3. Try clicking buttons in the UI
4. Check logs if something doesn't work
5. All 15 panels (Chat, Research, Admin, etc.) should now work through the proxy
