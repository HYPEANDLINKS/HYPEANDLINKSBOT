# RAG + Bot + AI integration

How the three services connect and which env vars to set so the bot uses RAG.

## Architecture

```
User (Telegram)
    ↓
  BOT (bot/bot.py)          ← needs: BOT_TOKEN, DATABASE_URL, AI_BACKEND_URL, API_KEY, APP_URL
    ↓ POST /api/chat
    ↓ X-API-Key: API_KEY
  AI (ai/backend/main.py)   ← needs: OLLAMA_URL, OLLAMA_MODEL, API_KEY, RAG_URL (optional)
    ↓ if RAG_URL set:
    ├─ POST RAG_URL/query (general questions) → context for system message
    └─ GET  RAG_URL/tokens/{symbol} (ticker e.g. TON, $USDT) → token facts
    ↓
  Ollama (local or same container)
```

- **Bot** never talks to RAG directly. It only calls the **AI** backend.
- **AI** backend, when `RAG_URL` is set, calls **RAG** for:
  - **General queries**: `POST /query` with `{ "query": "<user message>", "top_k": 5 }` → uses `context` + `sources` to build a system message for the model.
  - **Ticker queries** (e.g. `TON`, `$USDT`): `GET /tokens/{symbol}` → uses returned token data as verified facts in the prompt.

So to “connect them” you only need to:

1. Run **RAG** and set **AI**’s `RAG_URL` to that RAG base URL.
2. Keep **Bot** pointing at **AI** with `AI_BACKEND_URL` and `API_KEY`.

---

## Environment variables by service

### 1. RAG (`rag/backend/main.py`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RAG_STORE_PATH` | No | `rag_store.json` | Path to JSON file for ingested text docs. |
| `PROJECTS_STORE_PATH` | No | `projects_store.json` | Path to JSON file for project metadata. |
| `TOKENS_STORE_PATH` | No | `tokens_store.json` | Path to JSON file for token cache. |
| `TOKENS_API_URL` | No | `https://tokens.swap.coffee` | Base URL for token search API. |
| `TOKENS_API_KEY` | No | (none) | If the token API requires auth, set this. |

No env var is required for the bot or AI to “connect” to RAG; they only need the **URL** where RAG is running (see AI vars below).

Run RAG locally (example):

```bash
cd rag
pip install -r requirements.txt
uvicorn backend.main:app --host 0.0.0.0 --port 8001
```

Then RAG base URL is `http://localhost:8001` (or your deployed URL).

---

### 2. AI (`ai/backend/main.py`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_KEY` | **Yes** | — | Secret for `X-API-Key` header. Bot must use the same value. |
| `OLLAMA_URL` | No | `http://localhost:11434` | Ollama API base URL. |
| `OLLAMA_MODEL` | No | `llama3.2:3b` | Model name for chat. |
| `RAG_URL` | No | (none) | **Set this to use RAG.** Base URL of the RAG service (e.g. `http://localhost:8001` or `https://your-rag.up.railway.app`). No trailing slash. |
| `PORT` | No | `8000` | Port the AI backend listens on. |

To make the AI use RAG, set **only**:

- `RAG_URL` = base URL of the running RAG service.

The AI will then call `RAG_URL/query` and `RAG_URL/tokens/{symbol}` as needed.

---

### 3. Bot (`bot/bot.py`)

| Variable | Required | Description |
|----------|----------|-------------|
| `BOT_TOKEN` | **Yes** | Telegram bot token from BotFather. |
| `DATABASE_URL` | **Yes** | PostgreSQL connection string. |
| `AI_BACKEND_URL` | **Yes** (for AI) | Base URL of the **AI** backend (e.g. `http://localhost:8000` or `https://your-ai.up.railway.app`). No trailing slash. |
| `API_KEY` | **Yes** (for AI) | Same value as `API_KEY` in the AI service. Sent as `X-API-Key` to the AI. |
| `APP_URL` | No | Frontend URL for the “Run app” button. |

The bot does **not** need any RAG-specific env vars. It only needs to point at the AI backend; the AI backend uses RAG when `RAG_URL` is set.

---

## Minimal envs to “make it work with RAG”

**RAG (e.g. `rag/.env` or Railway vars):**

- Optional: `RAG_STORE_PATH`, `PROJECTS_STORE_PATH`, `TOKENS_STORE_PATH`, `TOKENS_API_URL`, `TOKENS_API_KEY` (only if you change paths or use a different token API).

**AI (e.g. `ai/.env` or Railway vars):**

- `API_KEY` = same secret you use in the bot.
- `RAG_URL` = base URL of the RAG service (e.g. `http://localhost:8001` or your deployed RAG URL).
- Optional: `OLLAMA_URL`, `OLLAMA_MODEL`, `PORT`.

**Bot (e.g. `bot/.env` or Railway vars):**

- `BOT_TOKEN`, `DATABASE_URL`, `AI_BACKEND_URL`, `API_KEY`, (optional) `APP_URL`.
- No RAG URL in the bot.

---

## Example: local (all three on one machine)

**Terminal 1 – RAG:**

```bash
cd rag && uvicorn backend.main:app --host 0.0.0.0 --port 8001
```

**Terminal 2 – AI:**

```bash
cd ai/backend
export API_KEY=your-shared-secret
export RAG_URL=http://localhost:8001
python main.py
# or: uvicorn main:app --host 0.0.0.0 --port 8000
```

**Terminal 3 – Bot:**

```bash
cd bot
export BOT_TOKEN=...
export DATABASE_URL=postgresql://...
export AI_BACKEND_URL=http://localhost:8000
export API_KEY=your-shared-secret
python bot.py
```

**Optional – seed RAG with projects:**

```bash
curl -X POST http://localhost:8001/ingest/source/allowlist
```

---

## Deploy RAG to Railway and get its link

The RAG service **does not set its own URL in code**. Railway assigns the public URL when you deploy.

### 1. Deploy the RAG service

- In Railway: New Project → Deploy from GitHub repo → choose the repo and set **Root Directory** to `rag` (so `rag/` is the project root).
- Railway will use `rag/railway.json` and run:  
  `uvicorn backend.main:app --host 0.0.0.0 --port $PORT`  
  (`$PORT` is set by Railway automatically; no code change needed.)

### 2. Where to see the link (RAG service URL)

- In the **Railway dashboard**: open your project → click the **RAG service** → **Settings** tab → **Networking** section.
- Click **Generate Domain**. Railway will show a URL like:  
  `https://rag-production-xxxx.up.railway.app`  
  or, if you added a custom domain, that domain.
- **Copy this URL** — this is your RAG service link. No need to put it in the RAG code.

### 3. Where to set the link (so the AI can call RAG)

Set it **as an environment variable in the AI service**, not in the RAG repo:

- **On Railway (recommended):** Open the **AI** service → **Variables** → add:
  - **Name:** `RAG_URL`
  - **Value:** the RAG URL from step 2 (e.g. `https://rag-production-xxxx.up.railway.app`) — **no trailing slash**.
- **Locally:** If the AI runs on your machine, set the same in the AI’s `.env` or shell:
  - `RAG_URL=https://rag-production-xxxx.up.railway.app`

Summary: the **link is shown by Railway** for the RAG service. You **set that link in the AI service** (Railway Variables or .env), not in the RAG code.

---

## Example: production (Railway / cloud)

- **RAG**: Deploy `rag/` (root directory = `rag`). Generate domain in Railway → note the URL (e.g. `https://your-rag.up.railway.app`).
- **AI**: Deploy `ai/`, in **Variables** set:
  - `API_KEY` = a strong shared secret.
  - `RAG_URL` = the RAG URL from above (no trailing slash).
- **Bot**: In **Variables** set:
  - `AI_BACKEND_URL` = your AI service URL (e.g. `https://your-ai.up.railway.app`),
  - `API_KEY` = same as AI.

No RAG URL in the bot; RAG is used only by the AI when `RAG_URL` is set.
