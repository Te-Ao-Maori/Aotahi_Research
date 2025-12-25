import json
import os
from typing import Any, Dict, List, Optional

import httpx
from httpx import HTTPStatusError

TIMEOUT = 30.0


class SupabaseClient:
    """Lightweight Supabase helper that respects realm-scoped credentials."""

    def __init__(
        self,
        project_url: Optional[str] = None,
        service_role_key: Optional[str] = None,
        anon_key: Optional[str] = None,
    ) -> None:
        self.project_url = project_url or os.getenv("SUPABASE_URL")
        # Prefer service role for writes, fall back to anon if explicitly provided
        self.api_key = service_role_key or os.getenv("SUPABASE_SERVICE_ROLE_KEY") or anon_key or os.getenv("SUPABASE_KEY")
        if not self.project_url or not self.api_key:
            raise ValueError("Supabase URL/key are required for database access")

    def _headers(self) -> Dict[str, str]:
        return {
            "apikey": self.api_key,
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    def insert_with_realm(self, table: str, payload: Dict[str, Any], realm_id: str) -> Dict[str, Any]:
        url = f"{self.project_url}/rest/v1/{table}"
        body = {**payload, "realm_id": realm_id}
        try:
            response = httpx.post(url, headers=self._headers(), json=body, timeout=TIMEOUT)
            response.raise_for_status()
            try:
                return response.json()
            except json.JSONDecodeError:
                return {}
        except HTTPStatusError as exc:
            print(f"[supabase] insert_with_realm failed for {table}: {exc}")
            return {}

    def rpc_match_embeddings(
        self,
        match_count: int,
        filter_realm_id: str,
        embedding: List[float],
        function_name: str = "match_research_embeddings",
    ) -> List[Dict[str, Any]]:
        url = f"{self.project_url}/rest/v1/rpc/{function_name}"
        payload = {
            "embedding": embedding,
            "match_count": match_count,
            "filter_realm_id": filter_realm_id,
        }
        try:
            response = httpx.post(url, headers=self._headers(), json=payload, timeout=TIMEOUT)
            response.raise_for_status()
            try:
                return response.json()
            except json.JSONDecodeError:
                return []
        except HTTPStatusError as exc:
            print(f"[supabase] RPC {function_name} failed: {exc}")
            return []
