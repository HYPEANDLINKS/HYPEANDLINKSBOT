from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os, json

app = FastAPI()

STORE_PATH = os.getenv("RAG_STORE_PATH", "rag_store.json")

def load_store() -> List[Dict[str, Any]]:
    if not os.path.exists(STORE_PATH):
        return []
    try:
        return json.loads(open(STORE_PATH, "r", encoding="utf-8").read())
    except:
        return []

def save_store(docs: List[Dict[str, Any]]) -> None:
    with open(STORE_PATH, "w", encoding="utf-8") as f:
        f.write(json.dumps(docs, ensure_ascii=False, indent=2))

class IngestDoc(BaseModel):
    text: str
    source: Optional[str] = None

class IngestRequest(BaseModel):
    documents: List[IngestDoc]

class QueryRequest(BaseModel):
    query: str
    top_k: int = 5

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/ingest")
async def ingest(req: IngestRequest):
    store = load_store()
    for d in req.documents:
        store.append({"text": d.text, "source": d.source or "unknown"})
    save_store(store)
    return {"ingested": len(req.documents), "total": len(store)}

@app.post("/query")
async def query(req: QueryRequest):
    store = load_store()
    q = req.query.lower().strip()
    q_words = set([w for w in q.split() if len(w) > 2])

    scored = []
    for item in store:
        text = item.get("text", "")
        t = text.lower()
        overlap = sum(1 for w in q_words if w in t)
        if overlap > 0:
            scored.append((overlap, item))

    scored.sort(key=lambda x: x[0], reverse=True)
    top = [x[1] for x in scored[: req.top_k]]

    # Return small snippets to keep responses light
    context = []
    sources = []
    for item in top:
        snippet = item["text"][:800]
        context.append(snippet)
        sources.append(item.get("source", "unknown"))

    return {"context": context, "sources": sources}
