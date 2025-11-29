# FAST GCRD SETUP - No unnecessary checks
param([string]$Code, [string]$Pin, [int]$Retries = 2)

$ErrorActionPreference = "Continue"

function GLog($msg) { Write-Host "[GCRD $(Get-Date -Format 'HH:mm:ss')] $msg" }

# FAST INSTALL - Skip signature checks
try {
    GLog "Turbo installing GCRD..."
    $msiPath = "$env:USERPROFILE\Downloads\crdhost.msi"
    
    if (Test-Path $msiPath) {
        Start-Process msiexec -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -NoNewWindow
        GLog "GCRD installation completed"
    }
} catch { 
    GLog "Installation note: $($_.Exception.Message)" 
}

# FAST REGISTRATION - Minimal retries
try {
    $crdExe = @("${env:ProgramFiles(x86)}","${env:ProgramFiles}") | 
        ForEach-Object { "$_\Google\Chrome Remote Desktop\CurrentVersion\remoting_start_host.exe" } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($crdExe -and $Code -and $Pin) {
        $token = $Code -replace '.*(4/[A-Za-z0-9_\-\.\~]+).*','$1'
        $display = "HappyMancing-$(Get-Date -Format 'HHmmss')"
        
        $args = @(
            "--code=`"$token`"",
            "--redirect-url=`"https://remotedesktop.google.com/_/oauthredirect`"",
            "--display-name=`"$display`"",
            "--pin=`"$Pin`"",
            "--disable-crash-reporting"
        ) -join ' '
        
        Start-Process -FilePath $crdExe -ArgumentList $args -Wait -NoNewWindow
        GLog "GCRD registration completed"
    }
} catch { 
    GLog "Registration note: $($_.Exception.Message)" 
}

GLog "GCRD setup finished"
Exit 0
