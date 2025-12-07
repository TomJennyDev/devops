# Download and install Kind binary
Write-Host "Downloading Kind..." -ForegroundColor Yellow

# Create temp directory
$tempDir = "$env:TEMP\kind-install"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Download Kind from GitHub releases
$kindVersion = "v0.20.0"
$kindUrl = "https://github.com/kubernetes-sigs/kind/releases/download/$kindVersion/kind-windows-amd64"
$kindPath = "$tempDir\kind.exe"

try {
    Write-Host "Downloading from: $kindUrl" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $kindUrl -OutFile $kindPath -UseBasicParsing
    Write-Host "Download completed" -ForegroundColor Green
    
    # Move to Windows directory
    $installPath = "C:\Windows\kind.exe"
    Copy-Item -Path $kindPath -Destination $installPath -Force
    
    Write-Host "Kind installed successfully!" -ForegroundColor Green
    Write-Host "Location: $installPath" -ForegroundColor Cyan
    
    # Verify
    & $installPath version
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

# Cleanup
Remove-Item -Recurse -Force $tempDir
