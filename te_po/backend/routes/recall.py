from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..schema.realms import RealmConfigLoader
from ..utils.recall_service import RecallService

router = APIRouter(tags=["recall"])


class RecallRequest(BaseModel):
    query: str
    thread_id: Optional[str] = None
    top_k: int = 5
    vector_store: str = "both"


class RecallResponse(BaseModel):
    matches: List[Dict[str, Any]]
    query_tokens: int
    recall_latency_ms: int


@router.post("/{realm_id}/recall", response_model=RecallResponse)
async def recall(realm_id: str, request: RecallRequest):
    try:
        config = RealmConfigLoader.load(realm_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Realm '{realm_id}' not found")
    if not config.features.get("recall"):
        raise HTTPException(status_code=403, detail="Recall disabled for this realm")
    service = RecallService(config)
    payload = {
        "query": request.query,
        "thread_id": request.thread_id,
        "top_k": request.top_k,
        "vector_store": request.vector_store,
    }
    return RecallResponse(**await service.run(payload))
