# ===== STOP LOCAL STACK (Windows) =====
# Stops services by killing whatever is LISTENING on ports:
# - 8000 (AI backend)
# - 8001 (RAG backend)
# - 11434 (Ollama) [optional]

param(
  [switch]$StopOllama
)

$ErrorActionPreference = "SilentlyContinue"

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
  if (-not $pids -or $pids.Count -eq 0) {
    Write-Host "  No process found for $reason."
    return
  }
  foreach ($procId in $pids) {
    Write-Host "  Killing PID $procId ($reason)..."
    try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {}
  }
}

function Kill-Port($port) {
  Write-Host "Checking port $port..."
  Stop-Pids (Get-ListeningPids $port) "port $port"
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
  Stop-Pids $pids "bot.py"
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

Write-Host "Done. Active listeners summary:"
foreach ($port in 8000, 8001, 11434) {
  $pids = Get-ListeningPids $port
  if ($pids.Count -gt 0) {
    Write-Host "  Port $port still in use by PID(s): $($pids -join ', ')"
  } else {
    Write-Host "  Port $port is free."
  }
}
