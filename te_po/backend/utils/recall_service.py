import os
import time
from typing import Any, Dict, List

import httpx

from ..db.supabase import SupabaseClient


class RecallService:
    def __init__(self, config):
        self.config = config
        self.openai_key = os.getenv("OPENAI_API_KEY")
        self.embedding_model = "text-embedding-3-large"
        supabase_cfg = config.supabase
        self.supabase_client = SupabaseClient(
            project_url=supabase_cfg.project_url,
            service_role_key=os.getenv("SUPABASE_SERVICE_ROLE_KEY"),
            anon_key=supabase_cfg.anon_key,
        )

    async def _embed(self, text: str) -> Dict[str, Any]:
        if not self.openai_key:
            raise RuntimeError("OpenAI key missing for recall service")
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                "https://api.openai.com/v1/embeddings",
                headers={
                    "Authorization": f"Bearer {self.openai_key}",
                    "Content-Type": "application/json",
                },
                json={"model": self.embedding_model, "input": text},
            )
        response.raise_for_status()
        payload = response.json()
        return {
            "embedding": payload["data"][0]["embedding"],
            "prompt_tokens": payload.get("usage", {}).get("prompt_tokens", len(text.split())),
        }

    async def search_openai(self, embedding: List[float], top_k: int) -> List[Dict[str, Any]]:
        # Placeholder: OpenAI vector search is disabled until vector_store_id/API access is configured.
        return []

    async def search_supabase(self, embedding: List[float], top_k: int) -> List[Dict[str, Any]]:
        return self.supabase_client.rpc_match_embeddings(
            embedding=embedding,
            match_count=top_k,
            filter_realm_id=self.config.realm_id,
        )

    async def log(self, query: str, matches: List[Dict[str, Any]], vector_store: str) -> None:
        table = self.config.supabase.tables.recall_logs
        self.supabase_client.insert_with_realm(
            table=table,
            payload={
                "query": query,
                "results_count": len(matches),
                "vector_store": vector_store,
                "response": matches,
            },
            realm_id=self.config.realm_id,
        )

    async def run(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        start = time.time()
        embedded = await self._embed(payload["query"])
        candidates: List[Dict[str, Any]] = []
        vector_store_setting = payload.get("vector_store") or self.config.recall_config.get("vector_store", "both")
        top_k = payload.get("top_k", 5)

        if vector_store_setting in {"openai", "both"}:
            candidates.extend(await self.search_openai(embedded["embedding"], top_k))
        if vector_store_setting in {"supabase", "both"} or self.config.recall_config.get("use_supabase_pgvector"):
            candidates.extend(await self.search_supabase(embedded["embedding"], top_k))

        candidates = sorted(candidates, key=lambda item: -item.get("score", 0.0))[:top_k]
        await self.log(payload["query"], candidates, vector_store_setting)
        return {
            "matches": candidates,
            "query_tokens": embedded["prompt_tokens"],
            "recall_latency_ms": int((time.time() - start) * 1000),
        }
