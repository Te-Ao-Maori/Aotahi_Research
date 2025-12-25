#!/bin/bash
# Quick dev startup for Māori Research Portal

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="/home/hemi-whiro/Titiraukawa/The_Awa_Network/te_po/core"

echo "🌍 Starting Māori Research Portal..."
echo ""

# Load env
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

# Check if .env is configured
if [[ -z "${TE_PO_URL}" ]]; then
  echo "❌ TE_PO_URL not set in .env"
  echo "   Copy .env.example to .env and configure it"
  exit 1
fi

# Kill old processes on ports
echo "Cleaning up old processes..."
lsof -ti tcp:8100 | xargs kill -9 2>/dev/null || true
lsof -ti tcp:5000 | xargs kill -9 2>/dev/null || true
lsof -ti tcp:8000 | xargs kill -9 2>/dev/null || true

# Start backend (Te Pó core)
echo ""
echo "🔧 Starting backend on :8000..."
cd "${BACKEND_DIR}"
python3 main.py &
BACKEND_PID=$!
echo "   PID: ${BACKEND_PID}"
sleep 2  # Give backend time to start

# Start proxy
echo ""
echo "🚀 Starting proxy on :8100..."
cd "${ROOT_DIR}"
(set -a; source "${ROOT_DIR}/.env"; set +a; PROXY_PORT=8100 python3 te_po/proxy/main.py) &
PROXY_PID=$!
echo "   PID: ${PROXY_PID}"
sleep 1  # Give proxy time to start

# Start frontend
echo ""
echo "🎨 Starting frontend on :5000..."
cd "${ROOT_DIR}/te_ao"
npm run dev -- --port 5000 &
FRONTEND_PID=$!
echo "   PID: ${FRONTEND_PID}"

echo ""
echo "✅ Māori Research Portal started!"
echo ""
echo "🔗 Frontend:  http://localhost:5000"
echo "🔗 Proxy:     http://localhost:8100"
echo "🔗 Backend:   http://localhost:8000"
echo ""
echo "📌 PIDs:"
echo "   Backend:  ${BACKEND_PID}"
echo "   Proxy:    ${PROXY_PID}"
echo "   Frontend: ${FRONTEND_PID}"
echo ""
echo "💡 To stop all services: kill ${BACKEND_PID} ${PROXY_PID} ${FRONTEND_PID}"
echo ""
echo ""
echo "Stop: kill $BACKEND_PID $FRONTEND_PID"
echo ""

wait
