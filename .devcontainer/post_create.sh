#!/bin/bash
set -e

echo "🌍 Māori Research Portal - Setting up dev environment..."

# Install Python dependencies
if [ -f "te_po_proxy/requirements.txt" ]; then
  echo "📦 Installing Python dependencies..."
  pip install --quiet -r te_po_proxy/requirements.txt
fi

# Install frontend dependencies
if [ -f "te_ao/package.json" ]; then
  echo "📦 Installing Node dependencies..."
  cd te_ao
  npm install --quiet
  cd ..
fi

# Create necessary directories
mkdir -p logs storage/{raw,clean,chunks}
echo "✅ Directories created"

# Show startup info
echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Update .env with your TE_PO_URL (port 8000) and BEARER_KEY"
echo "  2. Start backend on port 8000 (your main Te Pó repo)"
echo "  3. Run in this container:"
echo "     bash start_dev.sh"
echo ""
echo "🔗 Frontend: http://localhost:5000"
echo "🔗 Proxy: http://localhost:8100"
echo "🔗 Backend: http://localhost:8000"
