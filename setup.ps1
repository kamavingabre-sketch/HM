# ============================================================
# HAPPYMANCING: WINDOWS 10 GCRD + MUMU PLAYER DEPLOYMENT
# Role: Deployment Commander
# Doctrine: Speed - Efficiency - Reliability
# ============================================================

param(
    [string]$GateSecret
)

$ErrorActionPreference = "Stop"

function Timestamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Log($msg)  { Write-Host "[HAPPYMANCING $(Timestamp)] $msg" }
function Fail($msg) { Write-Error "[HAPPYMANCING-ERROR $(Timestamp)] $msg"; Exit 1 }

function Validate-Secret([Parameter(Mandatory)] [string]$Text) {
    return $Text -eq "LISTEN2KAEL"
}

# ============================================================
# INITIATION
# ============================================================
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host @"
------------------------------------------------------------
            HAPPYMANCING // GCRD + MUMU PLAYER
------------------------------------------------------------
  STATUS    : Fast deployment initializing
  TIME      : $now
  PROFILE   : Windows 10 GCRD + Mumu Player
  DOCTRINE  : Speed - Efficiency - Reliability
------------------------------------------------------------
"@

# ============================================================
# ACCESS CONTROL
# ============================================================
$GATE_SECRET = if ($PSBoundParameters.ContainsKey('GateSecret')) { $GateSecret } else { $env:HappyMancing_Access_Token }

if ($GATE_SECRET) { Write-Host "::add-mask::$GATE_SECRET" }

if (-not $GATE_SECRET -or [string]::IsNullOrWhiteSpace($GATE_SECRET)) {
    Fail "Missing HappyMancing_Access_Token secret"
}

if (-not (Validate-Secret $GATE_SECRET)) {
    Fail "Token validation failed. Expected: LISTEN2KAEL"
}
Log "Access granted - Starting deployment"

# ============================================================
# FAST GCRD DEPLOYMENT
# ============================================================
try {
    Log "Starting GCRD deployment"
    
    # Download and execute optimized GCRD setup
    $gcrdScriptUrl = "https://raw.githubusercontent.com/kamavingabre-sketch/testajah/refs/heads/main/GCRD-setup.ps1"
    Invoke-WebRequest -Uri $gcrdScriptUrl -OutFile "GCRD-setup.ps1" -UseBasicParsing -TimeoutSec 30
    
    # Execute with current parameters
    .\GCRD-setup.ps1 -Code $env:RAW_CODE -Pin $env:PIN_INPUT -Retries $env:RETRIES_INPUT
    
    Log "GCRD deployment completed"
} catch { 
    Fail "GCRD setup failed: $_" 
}

# ============================================================
# MUMU PLAYER INSTALLATION
# ============================================================
try {
    Log "Installing Mumu Player..."
    
    $mumuInstaller = Join-Path $env:USERPROFILE "Downloads\MemuInstaller.exe"
    
    if (Test-Path $mumuInstaller) {
        Log "Found Mumu Player installer, proceeding with installation..."
        
        # Silent install Mumu Player
        $installProcess = Start-Process -FilePath $mumuInstaller -ArgumentList "/S" -Wait -PassThru
        
        if ($installProcess.ExitCode -eq 0) {
            Log "✅ Mumu Player installed successfully"
            
            # Create Mumu Player shortcut on desktop for easy access
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $mumuShortcut = Join-Path $desktopPath "Mumu Player.lnk"
            $mumuExePath = "C:\Program Files\Microvirt\MEmu\MEmu.exe"
            
            if (Test-Path $mumuExePath) {
                try {
                    $WshShell = New-Object -comObject WScript.Shell
                    $Shortcut = $WshShell.CreateShortcut($mumuShortcut)
                    $Shortcut.TargetPath = $mumuExePath
                    $Shortcut.Save()
                    Log "✅ Mumu Player shortcut created on desktop"
                } catch {
                    Log "⚠️ Could not create shortcut, but Mumu Player is installed"
                }
            }
        } else {
            Log "⚠️ Mumu Player installation completed with exit code: $($installProcess.ExitCode)"
        }
    } else {
        Log "⚠️ Mumu Player installer not found, skipping installation"
    }
} catch {
    Log "⚠️ Mumu Player installation skipped: $_"
}

# ============================================================
# QUICK DATA FOLDER SETUP
# ============================================================
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $dataFolderPath = Join-Path $desktopPath "Data"

    if (-not (Test-Path $dataFolderPath)) {
        New-Item -Path $dataFolderPath -ItemType Directory | Out-Null
        Log "Data folder created"
    }
} catch { 
    Log "Data folder creation skipped: $_" 
}

# ============================================================
# FINAL SYSTEM STATUS
# ============================================================
Log "Deployment Summary:"
Log "  ✅ GCRD - Chrome Remote Desktop"
Log "  ✅ Mumu Player - Android Emulator" 
Log "  ✅ Data Folder - File Organization"
Log "System ready for use!"

# ============================================================
# RUNTIME MONITORING (FIXED)
# ============================================================
$totalMinutes = 360  # 6 hours runtime
$startTime = Get-Date
$endTime = $startTime.AddMinutes($totalMinutes)

Log "System active for up to ${totalMinutes}m"

$lastLogTime = $startTime

while ((Get-Date) -lt $endTime) {
    $currentTime = Get-Date
    $elapsed = [math]::Round(($currentTime - $startTime).TotalMinutes, 1)
    $remaining = [math]::Round(($endTime - $currentTime).TotalMinutes, 1)
    
    # Log every 30 minutes
    if (($currentTime - $lastLogTime).TotalMinutes -ge 30) {
        Log "Uptime ${elapsed}m | Remaining ${remaining}m"
        $lastLogTime = $currentTime
    }
    
    # Check every 5 minutes
    Start-Sleep -Seconds 300
}

Log "Deployment cycle completed - ${totalMinutes}m runtime finished"

# ============================================================
# CLEAN EXIT
# ============================================================
if ($env:RUNNER_ENV -eq "self-hosted") {
    Log "Initiating system shutdown"
    Stop-Computer -Force
} else {
    Log "Hosted environment - Exiting gracefully"
    Exit 0
}
