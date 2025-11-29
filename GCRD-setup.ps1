<#
 HAPPYMANCING: GCRD SETUP WITH OAuth FIX
 Role: Token Commander
 Objective: Handle OAuth errors and provide clear solutions
#>

param(
  [string]$Code,
  [string]$Pin = "123456",
  [int]$Retries = 2
)

$ErrorActionPreference = "Stop"

function Log([string]$msg)  { Write-Host "[GCRD $(Get-Date -Format 'HH:mm:ss')] $msg" }
function Fail([string]$msg) { Write-Error "[GCRD-ERROR] $msg"; exit 1 }

# ============================================================
# TOKEN VALIDATION & CLEANUP
# ============================================================
Log "Validating OAuth token..."

# Extract clean token from various input formats
function Get-CleanToken([string]$inputCode) {
    if ([string]::IsNullOrWhiteSpace($inputCode)) { return $null }
    
    # Pattern matching untuk berbagai format token
    $patterns = @(
        '--code="([^"]+)"',
        "--code='([^']+)'", 
        "--code=([^\s""'')]+)",
        '(4/[A-Za-z0-9_\-\.~]+)'
    )
    
    foreach ($pattern in $patterns) {
        if ($inputCode -match $pattern) {
            $token = $Matches[1].Trim('"',"'").Trim()
            if ($token -match '^4/') { return $token }
        }
    }
    
    return $null
}

$cleanToken = Get-CleanToken $Code
if (-not $cleanToken) {
    Fail "Invalid token format. Expected format: '4/xxxxxxxxxxx' or full headless command"
}

Log "Token extracted successfully"

# ============================================================
# CLEAN EXISTING GCRD INSTALLATION
# ============================================================
Log "Cleaning up previous GCRD installation..."

try {
    # Stop GCRD services
    $services = @("chrome_remote_desktop", "crd_service") 
    foreach ($service in $services) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Manual -ErrorAction SilentlyContinue
        } catch { /* Continue */ }
    }
    
    # Remove existing host configuration
    $crdPaths = @(
        "$env:ProgramData\Google\Chrome Remote Desktop",
        "$env:USERPROFILE\AppData\Local\Google\Chrome Remote Desktop",
        "$env:USERPROFILE\AppData\Roaming\Google\Chrome Remote Desktop"
    )
    
    foreach ($path in $crdPaths) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path "$path\host.json" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$path\host_unprivileged.json" -Force -ErrorAction SilentlyContinue
                Log "Cleaned: $path"
            } catch { /* Continue */ }
        }
    }
    
    # Kill any running GCRD processes
    Get-Process -Name "chrome_remote_desktop_host" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process -Name "remoting_start_host" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
} catch {
    Log "Cleanup warning: $($_.Exception.Message)"
}

# ============================================================
# GCRD INSTALLATION
# ============================================================
Log "Installing Chrome Remote Desktop..."

$msiPath = "$env:USERPROFILE\Downloads\crdhost.msi"
if (-not (Test-Path $msiPath)) {
    Fail "GCRD installer not found at $msiPath"
}

try {
    $installArgs = @("/i", "`"$msiPath`"", "/qn", "/norestart", "/L*v", "`"$env:TEMP\gcr_install.log`"")
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Log "First install attempt failed, trying repair..."
        $repairArgs = @("/fvomus", "`"$msiPath`"", "/qn", "/norestart")
        $repairProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $repairArgs -Wait -PassThru -NoNewWindow
        
        if ($repairProcess.ExitCode -ne 0) {
            Log "Check installation log: $env:TEMP\gcr_install.log"
            Fail "GCRD installation failed with code: $($repairProcess.ExitCode)"
        }
    }
    
    Log "GCRD installed successfully"
} catch {
    Fail "Installation failed: $($_.Exception.Message)"
}

# ============================================================
# LOCATE GCRD EXECUTABLE
# ============================================================
Log "Locating GCRD executable..."

$crdExe = $null
$searchPaths = @(
    "${env:ProgramFiles(x86)}\Google\Chrome Remote Desktop\CurrentVersion\remoting_start_host.exe",
    "${env:ProgramFiles}\Google\Chrome Remote Desktop\CurrentVersion\remoting_start_host.exe"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $crdExe = $path
        break
    }
}

if (-not $crdExe) {
    # Fallback search
    $found = Get-ChildItem -Path "C:\" -Filter "remoting_start_host.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $crdExe = $found.FullName }
}

if (-not $crdExe) {
    Fail "GCRD executable not found after installation"
}

Log "Found GCRD at: $crdExe"

# ============================================================
# GCRD REGISTRATION WITH SMART RETRY
# ============================================================
Log "Starting GCRD registration..."

$displayName = "HappyMancing-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$redirectUrl = "https://remotedesktop.google.com/_/oauthredirect"

$registrationArgs = @(
    "--code=`"$cleanToken`"",
    "--redirect-url=`"$redirectUrl`"",
    "--display-name=`"$displayName`"",
    "--pin=`"$Pin`"",
    "--disable-crash-reporting"
) -join ' '

$success = $false
$lastError = ""

for ($attempt = 1; $attempt -le $Retries; $attempt++) {
    Log "Registration attempt $attempt/$Retries"
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $crdExe
        $psi.Arguments = $registrationArgs
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit(60000) # 60 second timeout

        # Analyze output
        if ($process.ExitCode -eq 0) {
            Log "✅ Registration successful!"
            $success = $true
            break
        }

        # Error analysis
        $lastError = $stderr
        Log "Attempt $attempt failed with exit code: $($process.ExitCode)"
        
        if ($stderr -match "OAuth error" -or $stderr -match "invalid_grant" -or $stderr -match "Failed to exchange") {
            Log "❌ OAuth Token Error: Token is invalid or expired"
            Log "💡 Solution: Generate a NEW token from https://remotedesktop.google.com/headless"
            break # Don't retry on OAuth errors
        }
        
        if ($stderr -match "host_unprivileged.json") {
            Log "⚠️ Configuration file issue, retrying..."
        }
        
        if ($attempt -lt $Retries) {
            $waitTime = $attempt * 10
            Log "Waiting ${waitTime}s before retry..."
            Start-Sleep -Seconds $waitTime
        }
        
    } catch {
        $lastError = $_.Exception.Message
        Log "Attempt $attempt exception: $lastError"
        
        if ($attempt -lt $Retries) {
            Start-Sleep -Seconds (10 * $attempt)
        }
    }
}

# ============================================================
# FINAL VALIDATION
# ============================================================
if (-not $success) {
    if ($lastError -match "OAuth") {
        Fail @"
OAuth Token Error Detected!

🔴 PROBLEM: Your token is invalid, expired, or already used.

💡 SOLUTIONS:
1. Generate a NEW token from: https://remotedesktop.google.com/headless
2. Copy the FULL command (not just the token)
3. Run the workflow again with the new token

📝 Example of valid token format:
4/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Do not reuse old tokens - each token works only once!
"@
    } else {
        Fail "Registration failed after $Retries attempts. Last error: $lastError"
    }
}

# Verify host configuration
$hostConfig = "$env:ProgramData\Google\Chrome Remote Desktop\host.json"
if (Test-Path $hostConfig) {
    try {
        $config = Get-Content $hostConfig -Raw | ConvertFrom-Json
        if ($config.host_id) {
            $maskedId = $config.host_id.Substring(0,3) + "..." + $config.host_id.Substring($config.host_id.Length-3)
            Log "✅ Host registered successfully: $maskedId"
        }
    } catch {
        Log "Host configuration verified"
    }
}

Log "🎯 GCRD setup completed successfully!"
exit 0
