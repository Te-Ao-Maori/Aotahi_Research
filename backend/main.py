from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.routes.recall import router as recall_router

app = FastAPI(title="Aotahi Research Recall Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(recall_router)


@app.get("/health")
def health():
    return {"status": "ok", "service": "recall", "ready": True}
