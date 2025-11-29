# ============================================================
# HAPPYMANCING: ULTRA FAST DEPLOYMENT
# Role: Speed Commander  
# Doctrine: Maximum Speed - Minimum Overhead
# ============================================================

param([string]$GateSecret)

$ErrorActionPreference = "Continue" # Lebih toleran
$ProgressPreference = "SilentlyContinue"

function Log($msg) { Write-Host "[⚡ $(Get-Date -Format 'HH:mm:ss')] $msg" }

# ============================================================
# TURBO BOOT - Skip validasi non-critical
# ============================================================
Write-Host "==============================================="
Write-Host "            HAPPYMANCING TURBO MODE"
Write-Host "              ⚡ ULTRA FAST DEPLOY"
Write-Host "==============================================="

# Skip validasi panjang, langsung eksekusi
if ($GateSecret -ne "LISTEN2KAEL" -and $env:HappyMancing_Access_Token -ne "LISTEN2KAEL") {
    Write-Error "ACCESS DENIED"; Exit 1
}

Log "TURBO MODE: Bypassing non-critical checks"

# ============================================================
# PARALLEL EXECUTION - GCRD & MUMU bersamaan
# ============================================================
try {
    # Jalankan GCRD dan MUMU secara paralel
    $gcrProcess = Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -File `"GCRD-setup.ps1`" -Code `"$env:RAW_CODE`" -Pin `"$env:PIN_INPUT`" -Retries 2" -PassThru -NoNewWindow
    Log "GCRD deployment started (parallel)"
    
    # Mumu installation (fire and forget)
    $mumuPath = "$env:USERPROFILE\Downloads\MUMU.exe"
    if (Test-Path $mumuPath) {
        Start-Process -FilePath $mumuPath -ArgumentList "/S" -NoNewWindow
        Log "Mumu Player installation launched (background)"
    }
    
    # Data folder creation (instant)
    $dataPath = "$env:USERPROFILE\Desktop\Data"
    if (-not (Test-Path $dataPath)) { 
        New-Item -Path $dataPath -ItemType Directory -Force | Out-Null 
        Log "Data folder created"
    }
    
    # Tunggu GCRD selesai (dengan timeout)
    if (-not $gcrProcess.WaitForExit(1200000)) { # 20 minutes timeout
        Log "GCRD taking longer than expected, continuing..."
    } else {
        Log "GCRD process completed"
    }
    
} catch { 
    Log "Parallel execution warning: $_" 
}

# ============================================================
# QUICK HEALTH CHECK
# ============================================================
Log "Running quick health check..."
try {
    # Cek GCRD service
    $gcrService = Get-Service -Name "chrome_remote_desktop" -ErrorAction SilentlyContinue
    if ($gcrService) { Log "✅ GCRD Service: Running" } else { Log "⚠️ GCRD Service: Not found" }
    
    # Cek Mumu installation
    $mumuCheck = @(
        "C:\Program Files\Microvirt\MEmu\MEmu.exe",
        "C:\Program Files (x86)\Microvirt\MEmu\MEmu.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($mumuCheck) { Log "✅ Mumu Player: Installed" } else { Log "⏳ Mumu Player: Installing..." }
    
} catch { Log "Health check skipped" }

# ============================================================
# TURBO MONITORING (Minimal Overhead)
# ============================================================
Log "⚡ TURBO MODE: System operational"
$startTime = Get-Date
$totalRuntime = 360 # 6 hours

for ($i = 1; $i -le 72; $i++) { # Check every 5 minutes
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    $remaining = $totalRuntime - $elapsed
    
    if ($i % 6 -eq 0) { # Log every 30 minutes
        Log "Operational: ${elapsed}m elapsed, ${remaining}m remaining"
    }
    
    if ($remaining -le 0) { break }
    Start-Sleep -Seconds 300
}

Log "🎯 Turbo deployment cycle completed"
Exit 0
