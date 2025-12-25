#!/usr/bin/env python3
"""Generate the researcher + translator manifest files from .env."""

import json
import os
from pathlib import Path


def require(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise SystemExit(f"Missing required env var: {name}")
    return value


def write_json(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"✅ wrote {path}")


def realm_manifest(
    realm_id: str,
    assistant_id: str,
    vector_store_id: str,
    supabase_url: str,
    supabase_anon: str,
    recall_enabled: bool,
    display_name: str,
    description: str,
) -> dict:
    tables = {
        "sessions": "research_sessions",
        "notes": "research_notes",
        "chunks": "research_chunks",
        "embeddings": "research_embeddings",
        "recall_logs": "recall_logs",
    }

    return {
        "realm_id": realm_id,
        "display_name": display_name,
        "description": description,
        "te_po_url": os.getenv("TE_PO_URL", "http://localhost:5000"),
        "auth_mode": "bearer",
        "openai": {
            "assistant_id": assistant_id,
            "vector_store_id": vector_store_id,
        },
        "supabase": {
            "project_url": supabase_url,
            "anon_key": supabase_anon,
            "tables": tables,
        },
        "features": {
            "recall": recall_enabled,
            "vector_search": True,
            "pipeline": True,
            "memory": recall_enabled,
            "kaitiaki": False,
        },
        "recall_config": {
            "vector_store": "both",
            "top_k": 5,
            "use_supabase_pgvector": True,
        },
    }


def main() -> None:
    supabase_url = require("SUPABASE_URL")
    supabase_anon = os.getenv("SUPABASE_PUBLISHABLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not supabase_anon:
        raise SystemExit("Missing SUPABASE_PUBLISHABLE_KEY (preferred) or SUPABASE_ANON_KEY")

    researcher = realm_manifest(
        realm_id="researcher",
        assistant_id=require("OPENAI_ASSISTANT_ID_RESEARCHER"),
        vector_store_id=require("OPENAI_VECTOR_STORE_ID_RESEARCHER"),
        supabase_url=supabase_url,
        supabase_anon=supabase_anon,
        recall_enabled=True,
        display_name="Māori Research Realm",
        description="Realm for academic research with OpenAI Assistant + vector store access.",
    )

    translator = realm_manifest(
        realm_id="translator",
        assistant_id=require("OPENAI_ASSISTANT_ID_TRANSLATOR"),
        vector_store_id=require("OPENAI_VECTOR_STORE_ID_TRANSLATOR"),
        supabase_url=supabase_url,
        supabase_anon=supabase_anon,
        recall_enabled=False,
        display_name="Te Reo Translation Realm",
        description="Realm for Te Reo ↔ English translation, explanation, and pronunciation helpers.",
    )

    write_json(Path("mauri/realms/researcher/manifest.json"), researcher)
    write_json(Path("mauri/realms/translator/manifest.json"), translator)


if __name__ == "__main__":
    main()
