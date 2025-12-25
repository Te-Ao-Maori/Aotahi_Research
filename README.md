# Māori Research Portal

A dedicated realm for Māori cultural research, linguistics, and knowledge exploration.

## Quick Start

### Open in VS Code Dev Container

1. Open this folder in VS Code
2. Click "Reopen in Container" when prompted
3. Wait for setup to complete

### Manual Setup

```bash
# Install dependencies
pip install -r te_po_proxy/requirements.txt
cd te_ao && npm install && cd ..

# Update environment
cp .env.example .env
# Edit .env and set TE_PO_URL, BEARER_KEY, VITE_API_URL, VITE_PIPELINE_TOKEN, and VITE_OPENAI_KEY
```

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
python te_po_proxy/main.py
```

## Structure

- **mauri/**: State and configuration
  - `realm_manifest.json`: Realm identity and configuration
- **te_po_proxy/**: Backend proxy (forwards to main Te Pó)
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

- Deploy `te_po_proxy` to a hosting platform (Render, Railway, etc.)
- (Optional) Add a realm-specific UI under `te_ao/`
- Configure domain name and SSL
