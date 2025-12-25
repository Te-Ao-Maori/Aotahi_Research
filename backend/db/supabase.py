import json
import os
from typing import Any, Dict, List

import httpx
from httpx import HTTPStatusError

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
TIMEOUT = 30.0


def _headers() -> Dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise RuntimeError("Supabase credentials are required for recall logging")
    return {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }


def realm_insert(table: str, payload: Dict[str, Any], realm_id: str) -> Dict[str, Any]:
    headers = _headers()
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    body = {**payload, "realm_id": realm_id}
    try:
        response = httpx.post(url, headers=headers, json=body, timeout=TIMEOUT)
        response.raise_for_status()
        try:
            return response.json()
        except json.JSONDecodeError:
            return {}
    except HTTPStatusError as exc:
        print(f"[supabase] realm_insert failed for {table}: {exc}")
        return {}


def rpc_match_embeddings(**kwargs) -> List[Dict[str, Any]]:
    headers = _headers()
    url = f"{SUPABASE_URL}/rest/v1/rpc/match_research_embeddings"
    try:
        response = httpx.post(url, headers=headers, json=kwargs, timeout=TIMEOUT)
        response.raise_for_status()
        try:
            return response.json()
        except json.JSONDecodeError:
            return []
    except HTTPStatusError as exc:
        print(f"[supabase] RPC match_research_embeddings failed: {exc}")
        return []
