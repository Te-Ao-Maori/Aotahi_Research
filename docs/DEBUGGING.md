# Debugging Connection Issues

## Quick Diagnostic Checklist

```bash
# 1. Check if proxy is running
curl http://localhost:8000/health

# 2. Check if backend is accessible
curl http://localhost:5000/health

# 3. Check .env configuration
cat .env | grep -E "TE_PO_URL|BEARER_KEY|VITE_API_URL"

# 4. Test proxy can reach backend
curl -X POST http://localhost:8000/reo/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"Kia ora"}'
```

## Common Issues & Fixes

### Issue #1: "Failed to fetch" in Browser

**Symptom:** Click button → nothing happens → console shows error

**Diagnosis:**
1. Open **Browser DevTools** (F12 → Network tab)
2. Click a button (e.g., Translate)
3. Look for failed request

**Most Common Causes:**

**A) Proxy not running**
```
Error: Failed to connect to http://localhost:8000
```
Fix:
```bash
# Terminal 2
python te_po_proxy/main.py
# Should print: [te_po_proxy] Started for realm: maori_research
```

**B) Wrong TE_PO_URL in .env**
```
Error: HTTP 502 - Upstream error: Connection refused
```
Fix:
```bash
# Check what URL proxy is using
curl http://localhost:8000/health
# Example output: {"upstream":"http://localhost:8000"} ❌ WRONG

# Should be pointing to actual backend
# Edit .env:
TE_PO_URL=http://localhost:5000  # If local
# OR
TE_PO_URL=https://my-backend.example.com  # If remote

# Restart proxy
```

**C) Backend not running**
```
Error: HTTP 502 - Upstream error: Connection refused
```
Fix:
```bash
# Start your main Te Pó backend
# (This depends on your setup - could be Python Flask, FastAPI, Node.js, etc.)
# Usually something like:
python main.py  # or npm start, or docker-compose up
```

---

### Issue #2: "OpenAI down, Supabase down" in UI

**Symptom:** Status bar shows red X marks for services

**This is NOT a proxy issue** - it's your backend telling the frontend that IT can't reach those services.

**Diagnosis:**
- Check your **main Te Pó backend logs**
- Verify OpenAI API key is set in backend
- Verify Supabase connection strings are correct
- The proxy is just forwarding the response

---

### Issue #3: Auth/Token Issues (401 Unauthorized)

**Symptom:** Backend responds with 401 error

**Diagnosis:**
```bash
# Check what token proxy is sending
curl -v http://localhost:8000/health 2>&1 | grep Authorization
# (You won't see Authorization header because /health is a GET with no auth)

# Test with actual POST request
curl -v -X POST http://localhost:8000/reo/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"test"}' 2>&1 | grep Authorization
```

**Fix:**
```bash
# Make sure BEARER_KEY in .env matches backend's expected token
BEARER_KEY=your-actual-token-not-test-token

# Restart proxy
python te_po_proxy/main.py
```

---

### Issue #4: Request Timeout

**Symptom:** Click button → UI says "Thinking..." → Timeout error after 60 seconds

**Diagnosis:**
1. Check backend logs to see if request arrived
2. Is the backend processing slowly?
3. Did the proxy reach the backend?

**Fix:**
```bash
# Increase timeout in ChatPanel.jsx if needed
timeoutMs: 180000  # This is already 3 minutes

# OR check backend is responding
curl -X POST http://localhost:8000/reo/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"test"}' \
  --max-time 5  # Will show if backend is very slow
```

---

## Deep Debug: Enable Proxy Logging

Edit [te_po_proxy/main.py](te_po_proxy/main.py) and add logging:

```python
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("te_po_proxy")

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(path: str, request: Request):
    try:
        upstream_url = f"{te_po_url}/{path}"
        
        logger.debug(f"Proxying {request.method} {path}")
        logger.debug(f"Upstream URL: {upstream_url}")
        
        # ... rest of function
```

Then restart proxy and check terminal output.

---

## Test Each Layer Separately

### Layer 1: Frontend → Proxy

```bash
# In browser console:
fetch('http://localhost:8000/health')
  .then(r => r.json())
  .then(d => console.log(d))

# Should show:
// {status: 'ok', realm: 'maori_research', upstream: 'http://localhost:5000'}
```

### Layer 2: Proxy → Backend

```bash
# In terminal, test proxy connecting to backend
curl -X POST http://localhost:8000/status/full \
  -H "Authorization: Bearer test-token" \
  -H "Content-Type: application/json"

# Should get response from backend (not a 502 error)
```

### Layer 3: Frontend → All the Way

```bash
# Click a button in UI that requires no computation
# (e.g., "Sync" button which just lists recent documents)
# Watch the request go through all 3 layers
```

---

## Proxy Terminal Output Examples

### Good: Proxy forwarding successfully
```
[te_po_proxy] Started for realm: maori_research
[te_po_proxy] Upstream Te Pó: http://localhost:5000
```

### Bad: Can't reach backend
```
[te_po_proxy] Error proxying POST /reo/translate: Connection refused
```
→ Backend is not running or wrong URL

### Bad: Timeout
```
[te_po_proxy] Error proxying POST /kitenga/gpt-whisper: Read timed out
```
→ Backend is running but too slow

---

## Configuration Summary

For the buttons to work, you need:

| Component | Port | Status |
|-----------|------|--------|
| Frontend (React Vite) | 5173 | ✓ Running (`npm run dev`) |
| Proxy (FastAPI) | 8000 | ✓ Running (`python te_po_proxy/main.py`) |
| Main Te Pó Backend | 5000 | ✓ Running (check YOUR backend docs) |
| .env `TE_PO_URL` | - | ✓ Points to correct backend |
| .env `BEARER_KEY` | - | ✓ Matches backend's expected token |

If all 5 of these are green, buttons should work! 🚀

---

## Still Stuck?

Provide these details:

1. Output of: `curl http://localhost:8000/health`
2. Output of: `curl http://localhost:5000/health` (your backend)
3. What button you clicked
4. Browser console error (F12 → Console)
5. Proxy terminal output when you clicked the button
6. Your backend logs
