# Aotahi Research Portal - Project Summary & Setup Guide

## Overview

The Aotahi Research Portal is a sophisticated Māori cultural research platform built with a modern three-tier architecture. The project is designed to reconnect multiple research panels and tools through a unified API proxy that forwards requests to a main Te Pó backend. This document summarizes the project structure, the work completed, and the current operational status.

## Project Architecture

The system operates on a distributed architecture with three independent services:

**Frontend Layer (React + Vite)**
- Modern React 18 application with Vite build tooling
- Runs on port 5000 during development
- Provides user interface for 15 specialized research panels
- Communicates exclusively through the proxy layer
- Responsive design with TailwindCSS styling

**Proxy Layer (FastAPI)**
- Lightweight request forwarding service running on port 8100
- Acts as middleware between frontend and backend
- Handles authentication token injection
- Preserves all HTTP methods, headers, and request bodies
- Provides CORS support for cross-origin requests
- Implements error logging for troubleshooting

**Backend Layer (Main Te Pó)**
- External backend service running on port 8000
- Handles business logic, OpenAI integration, and API requests
- Processes requests for translation, summarization, vector search, and more
- Manages database connections (Supabase, Vector DB, Redis)
- Must be running independently on port 8000

## Completed Work

### 1. Repository Analysis & Architecture Documentation
- Scanned the entire repository structure
- Identified 15 specialized research panels (Chat, Research, Admin, RealmHealth, etc.)
- Documented the frontend's API call patterns and endpoints
- Created detailed architecture diagrams showing request flow

### 2. Proxy Implementation Fixes
**Previous Issues:**
- Proxy only supported GET requests
- Did not forward POST, PUT, DELETE, PATCH requests
- Ignored request bodies and query strings
- Pointed to itself instead of the actual backend

**Fixes Applied:**
- Implemented full HTTP method support (GET, POST, PUT, DELETE, PATCH)
- Added proper request body forwarding for JSON and form-data
- Preserved query strings in proxied requests
- Fixed upstream URL configuration to point to port 8000
- Added Bearer token injection for authentication
- Implemented comprehensive error logging for debugging
- Configured proper response header forwarding

### 3. Configuration Management
**Environment Variables Updated:**
- `TE_PO_URL=http://localhost:8000` - Points to actual backend
- `BEARER_KEY=test-token` - Authentication token for requests
- `VITE_API_URL=http://localhost:8100` - Frontend proxy endpoint
- `PROXY_PORT=8100` - Proxy service port
- `REALM_ID=maori_research` - Realm identification
- `REALM_NAME="Māori Research Portal"` - Properly quoted for shell compatibility

### 4. Development Script Enhancement
Updated `start_dev.sh` to:
- Properly source environment variables before starting services
- Launch frontend on port 5000 (changed from 5173)
- Launch proxy on port 8100 with environment variables loaded
- Clean up old processes on specified ports
- Display startup status with all three service URLs

### 5. Documentation Creation
- **SETUP_GUIDE.md** - Step-by-step configuration instructions
- **ARCHITECTURE.md** - Visual request flow diagrams and endpoint documentation
- **DEBUGGING.md** - Comprehensive troubleshooting guide with common issues
- **Devcontainer Configuration** - Updated for correct port mappings

## Frontend Panels & Capabilities

### Core Panels (15 total)
- **ChatPanel** - Main conversational interface with OpenAI integration
- **ResearchPanel** - Web and vector search combination
- **AdminPanel** - Administrative controls and monitoring
- **RealmHealthPanel** - System status and service health checks
- **TranslatePanel** - Te Reo ↔ English translation
- **PronunciationPanel** - Audio pronunciation guidance
- **ReoPanel** - Māori language utilities
- **VectorSearchPanel** - Semantic search across knowledge base
- **CulturalScanPanel** - Cultural context analysis
- **KaitiakiBuilderPanel** - Domain-specific tool builder
- **MemoryPanel** - Session and conversation history
- **IwiPortalPanel** - Iwi-specific features
- **SummaryPanel** - Content summarization
- **OCRPanel** - Image text extraction
- **TranslationPanel** - Comprehensive translation tools

### Button Actions Connected Through Proxy
| Action | Endpoint | Purpose |
|--------|----------|---------|
| Translate | `/reo/translate` | Language translation |
| Explain | `/reo/explain` | Contextual explanation |
| Pronounce | `/reo/pronounce` | Audio pronunciation |
| Summarize | `/kitenga/gpt-whisper` | Content summary via GPT-4 |
| Research | `/research/stacked` | Combined web + vector search |
| Web Search | Integrated in research | External web search |
| OCR | `/intake/ocr` | Image to text conversion |
| Recall | `/vector/search` | Semantic search retrieval |
| Sync | `/documents/profiles` | Load recent documents |
| Save Chat | `/chat/save-session` | Store conversation |

## Current Status

### ✅ Completed
- Proxy implementation with full HTTP support
- Environment configuration correctly set
- Port assignments finalized (frontend 5000, proxy 8100, backend 8000)
- Frontend successfully running with Vite dev server
- Proxy service running with proper environment variables loaded
- All 15 research panels available in UI
- Documentation complete and comprehensive
- Error logging operational for debugging

### ⏳ Next Steps
1. **Start Backend Service** - Your main Te Pó backend must be running on port 8000
2. **Verify Connectivity** - Test with `curl http://localhost:8100/health`
3. **Test UI Buttons** - Click translate/summarize buttons to verify end-to-end flow
4. **Monitor Logs** - Watch proxy terminal for successful request forwarding
5. **Troubleshoot Issues** - Use DEBUGGING.md guide for any connection problems

### ⚠️ Known Issues
- Workspace path has trailing space causing devcontainer label issues
- Fix: Rename folder or run locally instead of in devcontainer (recommended)
- Local development is faster and simpler for this project

## Quick Start Commands

**Terminal 1 - Frontend:**
```bash
cd te_ao && npm run dev
# Runs on http://localhost:5000
```

**Terminal 2 - Proxy:**
```bash
set -a && source .env && set +a && PROXY_PORT=8100 python3 te_po_proxy/main.py
# Runs on http://localhost:8100
```

**Terminal 3 - Backend:**
```bash
# Start your main Te Pó backend on port 8000
# Command depends on your backend setup
```

## Testing the Connection

1. **Check Proxy Health:**
   ```bash
   curl http://localhost:8100/health
   ```
   Expected: `{"status":"ok","realm":"maori_research","upstream":"http://localhost:8000"}`

2. **Test Frontend Loading:**
   - Open http://localhost:5000 in browser
   - Should see Kitenga Whiro interface with all panels

3. **Test Button Click:**
   - Type "Kia ora" in the text field
   - Click any button (Translate, Summarize, etc.)
   - Check browser console (F12) for success/error messages
   - Check proxy terminal for forwarded requests

4. **Monitor Proxy Logs:**
   Watch the proxy terminal output for messages like:
   ```
   [te_po_proxy] Started for realm: maori_research
   [te_po_proxy] Upstream Te Pó: http://localhost:8000
   INFO: Uvicorn running on http://0.0.0.0:8100
   ```

## Project Dependencies

**Frontend (Node.js):**
- React 18.3.1
- Vite 5.4.0
- TailwindCSS 3.4.0
- UUID 13.0.0
- PostCSS 8.4.32

**Proxy (Python):**
- FastAPI 0.104.1
- Uvicorn 0.24.0
- HTTPX 0.25.1
- Python-dotenv 1.0.0
- Python 3.12+

## File Structure

```
Aotahi_Research/
├── .env                          # Configuration (TE_PO_URL, BEARER_KEY, ports)
├── .devcontainer/                # VS Code devcontainer config
├── start_dev.sh                  # Development startup script
├── te_ao/                        # Frontend React application
│   ├── package.json
│   ├── vite.config.js
│   ├── src/
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   ├── panels/               # 15 specialized panels
│   │   ├── components/           # Reusable UI components
│   │   └── hooks/                # Custom React hooks (useApi, etc.)
│   └── public/                   # Static assets
├── te_po_proxy/                  # FastAPI proxy service
│   ├── main.py                   # Proxy server implementation
│   ├── bootstrap.py
│   ├── requirements.txt
│   └── Dockerfile
├── mauri/                        # Realm configuration
│   └── realm_manifest.json
└── Documentation files
    ├── README.md
    ├── SETUP_GUIDE.md
    ├── ARCHITECTURE.md
    ├── DEBUGGING.md
    └── PROJECT_SUMMARY.md
```

## Key Technical Decisions

1. **Three-Tier Architecture** - Separation of concerns allows independent scaling
2. **FastAPI Proxy** - Lightweight, async, perfect for request forwarding
3. **Port 8100 for Proxy** - Avoids conflicts with frontend (5000) and backend (8000)
4. **Environment-Based Configuration** - .env file for easy configuration without code changes
5. **Bearer Token Authentication** - Standardized auth injection at proxy level
6. **Comprehensive Logging** - Error logging in proxy for easy troubleshooting

## Support & Troubleshooting

Comprehensive guides available:
- **DEBUGGING.md** - Common issues and solutions
- **SETUP_GUIDE.md** - Configuration instructions
- **ARCHITECTURE.md** - Request flow visualization

All three services must be running simultaneously for full functionality. Frontend makes HTTP calls to proxy on port 8100, which forwards to backend on port 8000. Use the provided guides to verify each connection layer independently.

---

**Last Updated:** December 16, 2025  
**Status:** Ready for local development with all three services running
