# ===== START LOCAL STACK (Windows, robust) =====
param(
  [switch]$Reload,
  [switch]$ForegroundBot,
  [switch]$StopOllama
)

$ErrorActionPreference = "Stop"
Write-Host "start_local.ps1: launching local stack..."

function Get-ListeningPids($port) {
  $lines = netstat -ano | findstr ":$port" | findstr "LISTENING"
  if (-not $lines) { return @() }
  $pids = @()
  foreach ($line in $lines) {
    $parts = ($line -split "\s+") | Where-Object { $_ -ne "" }
    if ($parts.Count -gt 0) {
      $procId = $parts[-1]
      if ($procId -match "^\d+$") { $pids += [int]$procId }
    }
  }
  return $pids | Sort-Object -Unique
}

function Stop-Pids([int[]]$pids, [string]$reason) {
  foreach ($procId in ($pids | Sort-Object -Unique)) {
    try {
      Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      Write-Host "  Killed PID $procId ($reason)"
    } catch {}
  }
}

function Stop-BotProcesses {
  $botPids = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
    Where-Object CommandLine -Match "bot\.py" |
    Select-Object -ExpandProperty ProcessId -Unique
  Stop-Pids $botPids "bot.py"
}

$root = (Resolve-Path $PSScriptRoot).Path
$venvPython = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $venvPython)) {
  throw "Missing virtualenv python: $venvPython"
}

# REQUIRED env vars
$env:API_KEY        = "my-local-dev-secret"
$env:RAG_URL        = "http://127.0.0.1:8001"
$env:AI_BACKEND_URL = "http://127.0.0.1:8000"
$env:OLLAMA_URL     = "http://127.0.0.1:11434"
$env:OLLAMA_MODEL   = "qwen2.5:1.5b"
$env:BOT_TOKEN      = "8424280939:AAF5LpTE4p1roIU61NWAJJt7dKnYswaNFls"

$ragDir = Join-Path $root "rag\backend"
$aiDir  = Join-Path $root "ai\backend"
$botDir = Join-Path $root "bot"

if (-not (Test-Path -LiteralPath $ragDir)) { throw "Missing directory: $ragDir" }
if (-not (Test-Path -LiteralPath $aiDir)) { throw "Missing directory: $aiDir" }
if (-not (Test-Path -LiteralPath $botDir)) { throw "Missing directory: $botDir" }

Write-Host "Pre-cleanup..."
Stop-BotProcesses
Stop-Pids (Get-ListeningPids 8000) "port 8000"
Stop-Pids (Get-ListeningPids 8001) "port 8001"
if ($StopOllama) {
  Stop-Pids (Get-ListeningPids 11434) "port 11434"
}
Start-Sleep -Milliseconds 300

$reloadArgs = @()
if ($Reload) { $reloadArgs = @("--reload") }
$ragArgs = @("-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8001") + $reloadArgs
$aiArgs  = @("-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000") + $reloadArgs

$logDir = Join-Path $root ".logs\local"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$ragOutLog = (Join-Path $logDir "rag.ps.out.log")
$ragErrLog = (Join-Path $logDir "rag.ps.err.log")
$aiOutLog  = (Join-Path $logDir "ai.ps.out.log")
$aiErrLog  = (Join-Path $logDir "ai.ps.err.log")
$botOutLog = (Join-Path $logDir "bot.ps.out.log")
$botErrLog = (Join-Path $logDir "bot.ps.err.log")

$ragProc = Start-Process -FilePath $venvPython `
  -WorkingDirectory $ragDir `
  -ArgumentList $ragArgs `
  -RedirectStandardOutput $ragOutLog `
  -RedirectStandardError $ragErrLog `
  -PassThru

$aiProc = Start-Process -FilePath $venvPython `
  -WorkingDirectory $aiDir `
  -ArgumentList $aiArgs `
  -RedirectStandardOutput $aiOutLog `
  -RedirectStandardError $aiErrLog `
  -PassThru

if ($ForegroundBot) {
  Write-Host "Foreground bot mode enabled. Press Ctrl+C to stop all services."
  try {
    Push-Location $botDir
    & $venvPython "bot.py"
  } finally {
    Pop-Location
    Write-Host "Stopping services..."
    try { Stop-Process -Id $ragProc.Id -Force -ErrorAction SilentlyContinue; Write-Host "  Stopped RAG PID $($ragProc.Id)" } catch {}
    try { Stop-Process -Id $aiProc.Id -Force -ErrorAction SilentlyContinue; Write-Host "  Stopped AI PID $($aiProc.Id)" } catch {}
  }
  return
}

$botProc = Start-Process -FilePath $venvPython `
  -WorkingDirectory $botDir `
  -ArgumentList "bot.py" `
  -RedirectStandardOutput $botOutLog `
  -RedirectStandardError $botErrLog `
  -PassThru

Start-Sleep -Seconds 2
$ragUp = $false
$aiUp = $false
try { $null = Invoke-RestMethod -Uri "http://127.0.0.1:8001/health" -TimeoutSec 5; $ragUp = $true } catch {}
try { $null = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 5; $aiUp = $true } catch {}

Write-Host "Started processes:"
Write-Host "  RAG PID: $($ragProc.Id)  out: $([System.IO.Path]::GetFullPath($ragOutLog))  err: $([System.IO.Path]::GetFullPath($ragErrLog))"
Write-Host "  AI  PID: $($aiProc.Id)   out: $([System.IO.Path]::GetFullPath($aiOutLog))   err: $([System.IO.Path]::GetFullPath($aiErrLog))"
Write-Host "  Bot PID: $($botProc.Id)  out: $([System.IO.Path]::GetFullPath($botOutLog))  err: $([System.IO.Path]::GetFullPath($botErrLog))"
Write-Host "Health:"
Write-Host "  RAG /health: $(if ($ragUp) { 'OK' } else { 'FAILED' })"
Write-Host "  AI  /health: $(if ($aiUp) { 'OK' } else { 'FAILED' })"
if (-not $ragUp -or -not $aiUp) {
  Write-Host "One or more health checks failed. Inspect *.err.log files above." -ForegroundColor Yellow
}
