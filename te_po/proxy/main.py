"""
Te Pó Proxy - Realm-local backend proxy

This is a thin proxy that forwards requests to the main Te Pó backend.
It does NOT import or depend on Te Pó Python modules.
It reads TE_PO_URL from environment to determine the upstream.
"""

import os
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import httpx
from starlette.responses import Response

# Load environment
te_po_url = os.getenv("TE_PO_URL", "http://localhost:5000").rstrip("/")
bearer_key = os.getenv("BEARER_KEY", "")
realm_id = os.getenv("REALM_ID", "unknown")

app = FastAPI(
    title=f"Te Pó Proxy - {realm_id}",
    description="Thin proxy to main Te Pó backend"
)
LOG_TAG = "[te_po proxy]"

# CORS for realm UI
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    print(f"{LOG_TAG} Started for realm: {realm_id}")
    print(f"{LOG_TAG} Upstream Te Pó: {te_po_url}")


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "ok",
        "realm": realm_id,
        "upstream": te_po_url
    }


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(path: str, request: Request):
    """Proxy all requests to upstream Te Pó."""
    try:
        upstream_url = f"{te_po_url}/{path}"
        
        # Preserve query string
        if request.url.query:
            upstream_url = f"{upstream_url}?{request.url.query}"

        # Build headers
        headers = dict(request.headers)
        # Remove host header (it will be set by httpx for the new URL)
        headers.pop("host", None)
        
        # Add authorization if configured
        if bearer_key:
            headers["Authorization"] = f"Bearer {bearer_key}"
        
        # Handle request body
        body = None
        if request.method in ["POST", "PUT", "PATCH"]:
            # For all request types, pass the body as-is (httpx will handle form/json)
            body = await request.body()
        
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.request(
                request.method,
                upstream_url,
                headers=headers,
                content=body,
            )
            
            return Response(
                content=response.content,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.headers.get("content-type")
            )
    except Exception as e:
        print(f"{LOG_TAG} Error proxying {request.method} {path}: {str(e)}")
        raise HTTPException(
            status_code=502, detail=f"Upstream error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PROXY_PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
