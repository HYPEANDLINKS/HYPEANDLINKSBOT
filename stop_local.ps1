# ===== STOP LOCAL STACK (Windows) =====
# Stops services by killing whatever is LISTENING on ports:
# - 8000 (AI backend)
# - 8001 (RAG backend)
# - 11434 (Ollama) [optional]

param(
  [switch]$StopOllama
)

$ErrorActionPreference = "SilentlyContinue"

function Kill-Port($port) {
  Write-Host "Checking port $port..."
  $lines = netstat -ano | findstr ":$port" | findstr "LISTENING"
  if (-not $lines) {
    Write-Host "  No LISTENING process found on port $port."
    return
  }

  $pids = @()
  foreach ($line in $lines) {
    $parts = ($line -split "\s+") | Where-Object { $_ -ne "" }
    # PID is the last column
    $pid = $parts[-1]
    if ($pid -match "^\d+$") { $pids += $pid }
  }

  $pids = $pids | Sort-Object -Unique
  foreach ($procId in $pids) {
    Write-Host "  Killing PID $procId on port $port..."
    taskkill /PID $procId /F | Out-Null
  }
}

function Kill-BotProcess {
  Write-Host "Checking bot.py processes..."
  $botProcs = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
    Where-Object CommandLine -Match "bot\.py"

  if (-not $botProcs) {
    Write-Host "  No bot.py python process found."
    return
  }

  $pids = $botProcs | Select-Object -ExpandProperty ProcessId | Sort-Object -Unique
  foreach ($procId in $pids) {
    Write-Host "  Killing bot PID $procId..."
    taskkill /PID $procId /F | Out-Null
  }
}

# Always stop backend + rag
Kill-Port 8000
Kill-Port 8001
Kill-BotProcess

if ($StopOllama) {
  Kill-Port 11434
} else {
  Write-Host "Skipping Ollama (11434). Use: .\stop_local.ps1 -StopOllama"
}

Write-Host "Done."
