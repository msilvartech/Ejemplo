# Description: This script checks if the AzureAD module is installed. If not, it installs the module and forces the installation. Once installed the auth is performed.

# Check if the AzureAD module is installed
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Write-Host "AzureAD module not found. Installing now..." -ForegroundColor Yellow

    # Check if the user has the necessary permissions (admin rights) to install the module
    try {
        # Install AzureAD module (with force to ensure it's installed)
        Install-Module -Name AzureAD -Force -AllowClobber -Scope CurrentUser
        Write-Host "AzureAD module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error installing AzureAD module: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "AzureAD module is already installed. Proceeding with authentication..." -ForegroundColor Green
}

Connect-AzureAD -Identity
