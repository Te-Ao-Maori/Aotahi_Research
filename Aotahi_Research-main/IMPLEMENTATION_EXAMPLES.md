"""
Example implementation of realm config loader and recall gateway.
These are code patterns for Codex to use as a reference.
Place in your backend (te_po or main backend):
  - schema/realms.py (realm config loader)
  - routes/recall.py (recall gateway endpoint)
  - utils/recall_service.py (recall logic)
"""

# ============================================================================
# FILE: schema/realms.py
# ============================================================================
"""Load and cache realm configuration from realm_manifest.json files."""

import json
import os
from pathlib import Path
from typing import Optional, Dict, Any

class RealmConfig:
    """Represents a loaded realm configuration."""
    
    def __init__(self, data: Dict[str, Any]):
        self.realm_id: str = data.get("realm_id")
        self.display_name: str = data.get("display_name")
        self.te_po_url: str = data.get("te_po_url")
        self.openai: Dict = data.get("openai", {})
        self.supabase: Dict = data.get("supabase", {})
        self.features: Dict = data.get("features", {})
        self.recall_config: Dict = data.get("recall_config", {})
        self.translation_config: Dict = data.get("translation_config", {})
    
    @property
    def assistant_id(self) -> str:
        return self.openai.get("assistant_id")
    
    @property
    def vector_store_id(self) -> str:
        return self.openai.get("vector_store_id")
    
    @property
    def model(self) -> str:
        return self.openai.get("model", "gpt-4")


class RealmConfigLoader:
    """Load realm configs from manifest files."""
    
    _cache: Dict[str, RealmConfig] = {}
    
    @classmethod
    def load(cls, realm_id: str) -> Optional[RealmConfig]:
        """Load a realm config by ID, with caching."""
        if realm_id in cls._cache:
            return cls._cache[realm_id]
        
        # Try to load from environment variable first
        config_path = os.getenv(
            f"REALM_CONFIG_PATH_{realm_id.upper()}",
            f"mauri/realms/{realm_id}/manifest.json"
        )
        
        path = Path(config_path)
        if not path.exists():
            return None
        
        try:
            with open(path, "r") as f:
                data = json.load(f)
                config = RealmConfig(data)
                cls._cache[realm_id] = config
                return config
        except Exception as e:
            print(f"Error loading realm config {realm_id}: {e}")
            return None
    
    @classmethod
    def clear_cache(cls):
        """Clear the config cache (for testing)."""
        cls._cache.clear()


# ============================================================================
# FILE: utils/recall_service.py
# ============================================================================
"""Recall service: embed query, search vectors, merge results."""

import os
from typing import List, Dict, Any
import openai
from supabase import create_client, Client

class RecallService:
    """Unified recall across OpenAI vector store and Supabase pgvector."""
    
    def __init__(self, realm_config: RealmConfig):
        self.realm_id = realm_config.realm_id
        self.assistant_id = realm_config.assistant_id
        self.vector_store_id = realm_config.vector_store_id
        self.openai_model = realm_config.model
        
        # OpenAI client
        self.openai_client = openai.OpenAI(
            api_key=os.getenv("OPENAI_API_KEY")
        )
        
        # Supabase client (optional)
        supabase_url = realm_config.supabase.get("project_url") or os.getenv("SUPABASE_URL")
        supabase_key = realm_config.supabase.get("anon_key") or os.getenv("SUPABASE_KEY")
        self.supabase: Optional[Client] = None
        if supabase_url and supabase_key:
            self.supabase = create_client(supabase_url, supabase_key)
    
    async def recall(
        self,
        query: str,
        thread_id: Optional[str] = None,
        top_k: int = 5,
        vector_store: str = "openai"  # "openai", "supabase", "both"
    ) -> Dict[str, Any]:
        """
        Recall documents/chunks matching the query.
        
        Args:
            query: The search query
            thread_id: Optional OpenAI thread ID (for session context)
            top_k: Number of results to return
            vector_store: Which store(s) to search
        
        Returns:
            {
                "matches": [
                    {
                        "id": "...",
                        "source": "...",
                        "score": 0.92,
                        "snippet": "...",
                        "metadata": {...}
                    },
                    ...
                ],
                "query_tokens": 12,
                "recall_latency_ms": 145
            }
        """
        import time
        start_time = time.time()
        
        # Step 1: Embed the query
        embedding_response = self.openai_client.embeddings.create(
            model="text-embedding-3-small",  # or 3-large
            input=query
        )
        query_embedding = embedding_response.data[0].embedding
        query_tokens = embedding_response.usage.prompt_tokens
        
        # Step 2: Search vector stores
        matches = []
        
        if vector_store in ["openai", "both"]:
            matches.extend(
                await self._search_openai(query, top_k)
            )
        
        if vector_store in ["supabase", "both"] and self.supabase:
            matches.extend(
                await self._search_supabase(query_embedding, top_k)
            )
        
        # Step 3: Deduplicate & rank by score
        if vector_store == "both":
            seen = set()
            deduped = []
            for match in sorted(matches, key=lambda m: m["score"], reverse=True):
                key = (match["source"], match["snippet"][:50])
                if key not in seen:
                    seen.add(key)
                    deduped.append(match)
            matches = deduped[:top_k]
        
        # Step 4: Log the query (optional, to Supabase)
        await self._log_recall(query, len(matches))
        
        latency_ms = int((time.time() - start_time) * 1000)
        
        return {
            "matches": matches,
            "query_tokens": query_tokens,
            "recall_latency_ms": latency_ms
        }
    
    async def _search_openai(self, query: str, top_k: int) -> List[Dict[str, Any]]:
        """Search OpenAI vector store via assistant files."""
        # This is simplified; actual implementation depends on OpenAI files API
        # For now, use vector store directly if you have access to the API
        try:
            # Placeholder: you would call OpenAI Files API or Vector Store API
            # response = self.openai_client.beta.vector_stores.files.list(
            #     vector_store_id=self.vector_store_id
            # )
            # Then search for top_k matches
            return []  # Return empty for now
        except Exception as e:
            print(f"Error searching OpenAI vector store: {e}")
            return []
    
    async def _search_supabase(
        self,
        query_embedding: List[float],
        top_k: int
    ) -> List[Dict[str, Any]]:
        """Search Supabase pgvector for similar chunks."""
        if not self.supabase:
            return []
        
        try:
            # Call Supabase RPC function to search embeddings
            response = self.supabase.rpc(
                "match_research_embeddings",
                {
                    "query_embedding": query_embedding,
                    "match_count": top_k,
                    "filter_realm_id": self.realm_id
                }
            ).execute()
            
            matches = []
            for row in response.data:
                matches.append({
                    "id": row["chunk_id"],
                    "source": row["source_id"],
                    "score": float(row["similarity"]),
                    "snippet": row["content"][:200],
                    "metadata": row.get("metadata", {})
                })
            
            return matches
        except Exception as e:
            print(f"Error searching Supabase: {e}")
            return []
    
    async def _log_recall(self, query: str, results_count: int):
        """Log the recall query and results count (optional)."""
        if not self.supabase:
            return
        
        try:
            self.supabase.table("recall_logs").insert({
                "realm_id": self.realm_id,
                "query": query,
                "results_count": results_count,
                "created_at": "now()"
            }).execute()
        except Exception as e:
            print(f"Error logging recall: {e}")


# ============================================================================
# FILE: routes/recall.py
# ============================================================================
"""Recall gateway endpoint: POST /{realm_id}/recall"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from schema.realms import RealmConfigLoader
from utils.recall_service import RecallService

router = APIRouter(prefix="", tags=["recall"])

class RecallRequest(BaseModel):
    query: str
    thread_id: Optional[str] = None
    top_k: int = 5
    vector_store: str = "openai"  # "openai", "supabase", "both"

class RecallMatch(BaseModel):
    id: str
    source: str
    score: float
    snippet: str
    metadata: Dict[str, Any]

class RecallResponse(BaseModel):
    matches: List[RecallMatch]
    query_tokens: int
    recall_latency_ms: int

@router.post("/{realm_id}/recall", response_model=RecallResponse)
async def recall(realm_id: str, request: RecallRequest):
    """
    Unified recall gateway for a realm.
    
    POST /{realm_id}/recall
    {
      "query": "kōrero about traditional fishing",
      "thread_id": "thread_abc123",
      "top_k": 5,
      "vector_store": "openai"
    }
    
    Returns matches with source, score, and snippet.
    """
    # Load realm config
    realm_config = RealmConfigLoader.load(realm_id)
    if not realm_config:
        raise HTTPException(
            status_code=404,
            detail=f"Realm '{realm_id}' not found"
        )
    
    # Check that recall is enabled for this realm
    if not realm_config.features.get("recall", False):
        raise HTTPException(
            status_code=403,
            detail=f"Recall is not enabled for realm '{realm_id}'"
        )
    
    # Create recall service and execute
    recall_service = RecallService(realm_config)
    try:
        result = await recall_service.recall(
            query=request.query,
            thread_id=request.thread_id,
            top_k=request.top_k,
            vector_store=request.vector_store
        )
        
        return RecallResponse(
            matches=[RecallMatch(**m) for m in result["matches"]],
            query_tokens=result["query_tokens"],
            recall_latency_ms=result["recall_latency_ms"]
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Recall failed: {str(e)}"
        )

# ============================================================================
# FILE: main.py (modifications)
# ============================================================================
"""Include recall router in your FastAPI app."""

from fastapi import FastAPI
from routes import recall  # Import the recall router

app = FastAPI(title="Te Pó Backend")

# Include the recall router
app.include_router(recall.router)

# Your other routes...
# @app.post("/reo/translate")
# @app.post("/kitenga/ask")
# etc.

# ============================================================================
# INTEGRATION EXAMPLE: ChatPanel.jsx
# ============================================================================
"""
In your React frontend (ChatPanel.jsx), replace /vector/search with /recall:

OLD:
const vector = await callApi("/vector/search", {
  method: "POST",
  body: JSON.stringify({ query: userMessage })
});

NEW:
const realmId = "researcher"; // or from context/config
const vector = await callApi(`/${realmId}/recall`, {
  method: "POST",
  body: JSON.stringify({
    query: userMessage,
    thread_id: currentThreadId,
    top_k: 5,
    vector_store: "openai"
  })
});

// Compose context from matches
const context = vector.matches
  .map(m => `${m.source}: ${m.snippet}`)
  .join("\n\n");

// Then call assistant with context
const response = await callApi("/kitenga/ask", {
  method: "POST",
  body: JSON.stringify({
    message: userMessage,
    context: context,
    thread_id: currentThreadId,
    realm_id: realmId
  })
});
"""

# ============================================================================
# NOTES FOR IMPLEMENTATION
# ============================================================================
"""
1. RealmConfigLoader caches configs in memory. For production, add TTL or reload on demand.

2. RecallService._search_openai() is simplified because OpenAI's Vector Store API
   isn't fully exposed in the Python SDK yet. Options:
   a) Use Files API to search uploaded documents
   b) Use a custom vector search via OpenAI Embeddings + vector DB
   c) Use Assistants API with file retrieval (automatic, but less control)

3. _search_supabase() assumes you have a Postgres function:
   match_research_embeddings(query_embedding, match_count, filter_realm_id)
   which does similarity search using pgvector.

4. For the pgvector function, you'd add to Supabase:
   
   CREATE OR REPLACE FUNCTION match_research_embeddings(
     query_embedding VECTOR,
     match_count INT,
     filter_realm_id TEXT
   ) RETURNS TABLE(chunk_id UUID, source_id TEXT, content TEXT, similarity FLOAT, metadata JSONB) AS $$
   BEGIN
     RETURN QUERY
     SELECT
       re.chunk_id,
       rc.source_id,
       rc.content,
       1 - (re.embedding <=> query_embedding) AS similarity,
       rc.metadata
     FROM research_embeddings re
     JOIN research_chunks rc ON rc.id = re.chunk_id
     WHERE re.realm_id = filter_realm_id
     ORDER BY re.embedding <=> query_embedding
     LIMIT match_count;
   END;
   $$ LANGUAGE plpgsql;

5. Error handling: Add proper logging and monitoring. Consider adding:
   - Sentry for exception tracking
   - CloudWatch/DataDog for latency monitoring
   - Log levels (DEBUG, INFO, WARN, ERROR)

6. Testing: Write tests for:
   - RealmConfigLoader.load() with valid/invalid realm IDs
   - RecallService.recall() with mocked OpenAI/Supabase
   - recall() endpoint with valid/invalid requests

7. Migration path:
   - Start with OpenAI vector store only (simple)
   - Later, add Supabase pgvector if you need analytics/multi-realm search
   - Use vector_store="both" for gradual migration
"""
