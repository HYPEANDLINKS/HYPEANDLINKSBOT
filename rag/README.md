# RAG Service (Skeleton)

Run locally:
pip install -r requirements.txt
uvicorn backend.main:app --reload --port 8001

Endpoints:
GET /health
POST /ingest
POST /query
