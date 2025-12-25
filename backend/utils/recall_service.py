import os
import time
from typing import Any, Dict, List, Optional

import httpx

from backend.db.supabase import realm_insert, rpc_match_embeddings
from backend.schema.realms import RealmConfigLoader


class RecallService:
    def __init__(self, config):
        self.config = config
        self.openai_key = os.getenv("OPENAI_API_KEY")
        self.embedding_model = "text-embedding-3-large"

    async def _embed(self, text: str) -> List[float]:
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
        return payload["data"][0]["embedding"]

    async def search_openai(self, embedding: List[float], top_k: int) -> List[Dict[str, Any]]:
        return []

    async def search_supabase(self, embedding: List[float], top_k: int) -> List[Dict[str, Any]]:
        return rpc_match_embeddings(
            embedding=embedding,
            match_count=top_k,
            filter_realm_id=self.config.realm_id,
        )

    async def log(self, query: str, matches: List[Dict[str, Any]], vector_store: str) -> None:
        table = self.config.supabase.tables.recall_logs
        realm_insert(
            table=table,
            payload={
                "query": query,
                "matches": len(matches),
                "vector_store": vector_store,
                "response": matches,
            },
            realm_id=self.config.realm_id,
        )

    async def run(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        start = time.time()
        embedding = await self._embed(payload["query"])
        candidates: List[Dict[str, Any]] = []
        vector_store_setting = payload.get("vector_store") or self.config.recall_config.get("vector_store", "both")
        if vector_store_setting in {"openai", "both"}:
            candidates.extend(await self.search_openai(embedding, payload.get("top_k", 5)))
        if vector_store_setting in {"supabase", "both"} or self.config.recall_config.get("use_supabase_pgvector"):
            candidates.extend(await self.search_supabase(embedding, payload.get("top_k", 5)))
        candidates = sorted(candidates, key=lambda item: -item.get("score", 0.0))[: payload.get("top_k", 5)]
        await self.log(payload["query"], candidates, vector_store_setting)
        return {
            "matches": candidates,
            "query_tokens": len(payload["query"].split()),
            "recall_latency_ms": int((time.time() - start) * 1000),
        }
