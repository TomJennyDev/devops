# ============================================
# Install Prerequisites for EKS Local
# Run as Administrator
# ============================================

Write-Host "Installing EKS Local Prerequisites..." -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Please run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "Chocolatey installed successfully" -ForegroundColor Green

# Install packages
$packages = @(
    "docker-desktop",
    "kubernetes-cli",
    "kubernetes-helm",
    "kind",
    "git"
)

foreach ($package in $packages) {
    Write-Host "Installing $package..." -ForegroundColor Yellow
    choco install $package -y
}

Write-Host ""
Write-Host "All prerequisites installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Close and reopen your terminal"
Write-Host "2. Start Docker Desktop"
Write-Host "3. Run: bash create-cluster.sh"
Write-Host ""
Write-Host "Verify installation:" -ForegroundColor Cyan
Write-Host "docker --version"
Write-Host "kubectl version --client"
Write-Host "helm version"
Write-Host "kind version"
