#!/bin/bash
set -euo pipefail

ROOT="$(pwd)"
BACKEND_DIR="${BACKEND_DIR:-/home/hemi-whiro/Titiraukawa/The_Awa_Network/te_po}"
FRONTEND_DIR="$ROOT/te_ao"

BACKEND_PID=""
PROXY_PID=""
FRONTEND_PID=""

cleanup() {
  echo "Stopping services..."
  for pid in "$BACKEND_PID" "$PROXY_PID" "$FRONTEND_PID"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}

trap cleanup EXIT

start_backend() {
  if [[ -d "$BACKEND_DIR" ]]; then
    echo "Starting backend from ${BACKEND_DIR}..."
    (cd "$BACKEND_DIR" && python main.py) &
    BACKEND_PID=$!
  else
    echo "Backend directory ${BACKEND_DIR} not found; skipping backend start."
  fi
}

start_proxy() {
  if [[ -f "$ROOT/.env" ]]; then
    echo "Starting proxy (te_po/proxy/main.py) on port 8100..."
    (set -a; source "$ROOT/.env"; set +a; PROXY_PORT=8100 python te_po/proxy/main.py) &
    PROXY_PID=$!
  else
    echo ".env file missing at ${ROOT}; cannot start proxy."
    exit 1
  fi
}

start_frontend() {
  echo "Starting frontend (te_ao Vite) on port 5000..."
  (
    cd "$FRONTEND_DIR"
    VITE_API_URL="http://localhost:8100" npm run dev -- --host 0.0.0.0 --port 5000
  ) &
  FRONTEND_PID=$!
}

echo "Launching local services (backend, proxy, frontend)..."
start_backend
start_proxy
start_frontend

echo "Services are running for 8 seconds to confirm startup..."
sleep 8

echo "Done; exiting script to clean up."
