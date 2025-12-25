import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

from pydantic import BaseModel, Field


class SupabaseTables(BaseModel):
    sessions: str = "research_sessions"
    notes: str = "research_notes"
    chunks: str = "research_chunks"
    embeddings: str = "research_embeddings"
    recall_logs: str = "recall_logs"


class SupabaseConfig(BaseModel):
    project_url: Optional[str]
    anon_key: Optional[str]
    tables: SupabaseTables = Field(default_factory=SupabaseTables)


class RealmConfig(BaseModel):
    realm_id: str
    display_name: Optional[str]
    te_po_url: Optional[str]
    auth_mode: Optional[str] = "bearer"
    openai: Dict[str, str] = Field(default_factory=dict)
    supabase: SupabaseConfig = Field(default_factory=SupabaseConfig)
    features: Dict[str, bool] = Field(default_factory=dict)
    recall_config: Dict[str, Any] = Field(default_factory=dict)


class RealmConfigLoader:
    _cache: Dict[str, RealmConfig] = {}

    @classmethod
    def _manifest_path(cls, realm_id: str) -> Path:
        env_key = f"REALM_CONFIG_PATH_{realm_id.upper()}"
        candidate = os.getenv(env_key)
        if not candidate:
            candidate = os.getenv("REALM_CONFIG_PATH")
        if not candidate:
            candidate = f"mauri/realms/{realm_id}/manifest.json"
        return Path(candidate)

    @classmethod
    def load(cls, realm_id: str) -> RealmConfig:
        if realm_id in cls._cache:
            return cls._cache[realm_id]
        manifest_path = cls._manifest_path(realm_id)
        if not manifest_path.exists():
            raise FileNotFoundError(f"Realm manifest not found: {manifest_path}")
        raw = json.loads(manifest_path.read_text())
        supabase_data = raw.get("supabase") or {}
        tables_data = supabase_data.get("tables") or {}
        supabase_data["tables"] = tables_data
        config = RealmConfig(
            realm_id=raw.get("realm_id", realm_id),
            display_name=raw.get("display_name"),
            te_po_url=raw.get("te_po_url"),
            auth_mode=raw.get("auth_mode", "bearer"),
            openai=raw.get("openai", {}),
            supabase=SupabaseConfig(**supabase_data),
            features=raw.get("features", {}),
            recall_config=raw.get("recall_config", {}),
        )
        cls._cache[realm_id] = config
        return config
