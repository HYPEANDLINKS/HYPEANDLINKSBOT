This is a monorepo containing multiple services.

## How to fork and contribute?

1.Install GitHub CLI and authorize to GitHub from cli for instant work

```
winget install --id GitHub.cli
gh auth login
``

2. Fork the repo, clone it and create a new branch and switch to it

```
gh repo fork https://github.com/HyperlinksSpace/HyperlinksSpaceBot.git --clone
git checkout -b new-branch-for-an-update
git switch -c new-branch-for-an-update
```

3. After making a commit, make a pull request, gh tool will already know the upstream remote

```
gh pr create --title "My new PR" --body "It is my best PR"
```

## Localhost deploy

Create a bot using @BotFather. Copy bot token and set them in the 446th line of start_local.ps1 in the root directory of the project.

Run the script to start on localhost

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:/1/HyperlinksSpaceBot/start_local.ps1" -LogsInServiceWindows
```

Run the script to stop on localhost

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:/1/HyperlinksSpaceBot/stop_local.ps1"
```

## Repository Structure

```
HyperlinksSpaceBot/
├── ai/                    # AI backend (FastAPI)
│   └── backend/
├── bot/                   # Telegram bot + bot HTTP API
├── front/                 # Flutter web frontend (Mini App UI)
├── rag/                   # RAG backend (FastAPI)
│   └── backend/
├── docs/                  # Project docs
├── start_local.ps1        # Main local stack launcher (Windows)
├── stop_local.ps1         # Local stack stop/cleanup script (Windows)
├── smoke_test.ps1         # Local smoke checks (PowerShell)
└── smoke_test.sh          # Local smoke checks (bash)
```

## Runtime Architecture

Local stack runs these services:

- `rag/backend` (FastAPI): token/project retrieval for grounding
- `ai/backend` (FastAPI): chat backend that calls RAG and LLM provider
- `bot/bot.py`:
  - Telegram bot polling worker
  - HTTP API server on port `8080` for frontend calls
- `front` (Flutter web-server): Mini App frontend on port `3000`
- `ollama` (optional external/local process): default LLM provider in local mode

Request path in local mode:

`Frontend -> Bot HTTP API (:8080) -> AI backend (:8000) -> RAG (:8001) [+ Ollama/OpenAI]`

## Local Scripts

### `start_local.ps1`

Starts local stack, writes/streams logs, performs readiness checks, and opens frontend in browser when ready.

Supported switches:

- `-Reload` - enables `uvicorn --reload` for AI and RAG
- `-ForegroundBot` - runs bot in current terminal (Ctrl+C stops services)
- `-StopOllama` - stops existing Ollama listener during pre-cleanup
- `-OpenLogWindows` - opens separate log-tail windows for services
- `-LogsInServiceWindows` - shows logs in service process windows instead of redirected log files

### `stop_local.ps1`

Stops the local stack robustly by:

- killing listeners on service ports (`3000`, `8000`, `8001`, `8080`, optionally `11434`)
- killing known bot/flutter/backend processes
- killing repo-scoped leftover runtime processes and log-tail windows

Switch:

- `-KeepOllama` - keeps `11434` listener alive

## Local Ports and Health Checks

- `3000` - frontend (`http://127.0.0.1:3000`)
- `8000` - AI backend
- `8001` - RAG backend
- `8080` - bot HTTP API (`/health`)
- `11434` - Ollama API (when using `LLM_PROVIDER=ollama`)

`start_local.ps1` reports readiness for:

- RAG `/health`
- AI root endpoint
- Bot API `/health`
- Frontend availability
- Ollama model presence (when Ollama provider is active)

## Key Environment Variables (Local)

- `BOT_TOKEN` - Telegram bot token
- `SELF_API_KEY` / `API_KEY` - shared key between frontend/bot/AI API calls
- `AI_BACKEND_URL` - defaults to `http://127.0.0.1:8000`
- `RAG_URL` - defaults to `http://127.0.0.1:8001`
- `HTTP_PORT` - bot API port (default `8080`)
- `APP_URL` - URL used for Telegram "Run app" button (defaults to local frontend URL)
- `LLM_PROVIDER` - `ollama` (default in local script) or `openai`
- `OLLAMA_URL`, `OLLAMA_MODEL` - Ollama runtime/model settings
- `OPENAI_API_KEY`, `OPENAI_MODEL` - OpenAI mode settings

## Frontend Deploy Flow

Current frontend deploy helper scripts in `front/` are Vercel-oriented:

- `front/deploy.sh`
- `front/deploy.bat`

`start_local.ps1` also prints this flow after startup:

1. `cd front`
2. `bash deploy.sh` (or `.\deploy.bat` on Windows)

## Quick Local Verification

After stack startup:

1. Open `http://127.0.0.1:3000`
2. Check bot API health: `http://127.0.0.1:8080/health`
3. In Telegram, run `/start` and tap "Run app"
4. Send test prompts in chat (for example `$DOGS`, `$TON`)

Expected:

- frontend loads and can call bot API
- bot answers without API key errors
- AI backend responds and can access RAG for token lookups
