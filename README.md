# Māori Research Portal

A dedicated realm for Māori cultural research, linguistics, and knowledge exploration.

## Quick Start

### Open in VS Code Dev Container

1. Open this folder in VS Code
2. Click "Reopen in Container" when prompted
3. Wait for setup to complete

### Manual Setup

```bash
# Install Python dependencies
pip install -r te_po/backend/requirements.txt -r te_po/proxy/requirements.txt
cd te_ao && npm install && cd ..

# Update environment
cp .env.example .env
# Edit .env and set TE_PO_URL, BEARER_KEY, VITE_API_URL, VITE_PIPELINE_TOKEN, and VITE_OPENAI_KEY
```
> ⚠️ Keep `.env` local and **never commit it**; treat `.env.example` as the shared template.

## Documentation

Detailed design, setup, and implementation notes live under `docs/`. Start with `docs/START_HERE.md` for the curated reading order.

## Running

**Terminal 1 - Frontend:**
```bash
cd te_ao
npm run dev
```

**Terminal 2 - Backend Proxy:**
```bash
python te_po/proxy/main.py
```

## Structure

- **mauri/**: State and configuration
  - `realm_manifest.json`: Realm identity and configuration
- **te_po/backend/**: Recall-focused FastAPI service
  - `main.py`: FastAPI app with recall router
  - `routes/recall.py`: `/recall` gateway logic
  - `db/`, `schema/`, `utils/`: helpers for Supabase, configs, embeddings
- **te_po/proxy/**: Realm-specific backend proxy (forwards to main Te Pó)
  - `main.py`: FastAPI proxy server
  - `bootstrap.py`: Initialization script
  - `requirements.txt`: Python dependencies
- **.env**: Realm configuration (create from .env.example)

## Optional: Add Frontend

To add a React frontend to this realm:

```bash
npm create vite@latest te_ao -- --template react
cd te_ao
npm install
```

Then update `VITE_API_URL` in `.env` to point to the proxy.

## Connecting to Main Te Pó

The proxy forwards all requests to the upstream Te Pó backend specified in `TE_PO_URL`.

Authentication uses the `BEARER_KEY` from `.env`, automatically added to all requests.

## Next Steps

- Deploy `te_po/proxy` to a hosting platform (Render, Railway, etc.)
- (Optional) Add a realm-specific UI under `te_ao/`
- Configure domain name and SSL
