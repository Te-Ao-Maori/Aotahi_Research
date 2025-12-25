#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_PORT=8100
FRONTEND_PORT=5000

kill_port() {
  local port=$1
  local pid
  pid=$(lsof -ti tcp:"$port" || true)
  if [[ -n "$pid" ]]; then
    echo "Killing process on port $port (PID $pid)"
    kill "$pid" 2>/dev/null || true
  fi
}

cleanup() {
  echo "Stopping proxy and frontend..."
  kill_port "$PROXY_PORT"
  kill_port "$FRONTEND_PORT"
}

trap cleanup EXIT INT TERM

echo "Clearing previous listeners..."
kill_port "$PROXY_PORT"
kill_port "$FRONTEND_PORT"

start_proxy() {
  echo "Starting proxy on port ${PROXY_PORT}..."
  (set -a; source "$ROOT/.env"; set +a; PROXY_PORT="$PROXY_PORT" python "$ROOT/te_po_proxy/main.py") &
  PROXY_PID=$!
  sleep 1
}

start_frontend() {
  echo "Starting frontend on port ${FRONTEND_PORT}..."
  (
    cd "$ROOT/te_ao"
    VITE_API_URL="http://localhost:${PROXY_PORT}" npm run dev -- --host 0.0.0.0 --port "$FRONTEND_PORT"
  ) &
  FRONTEND_PID=$!
}

start_proxy
start_frontend

echo "Proxy PID: ${PROXY_PID:-n/a}, Frontend PID: ${FRONTEND_PID:-n/a}"
echo "Press Ctrl+C to stop."

wait
