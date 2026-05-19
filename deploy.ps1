# Deploy AI Foundry + AI Search with Private Endpoints
# This script prompts for all required parameters before deploying.

Write-Host "=== AI Foundry + AI Search Private Network Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for parameters
$SubscriptionId = Read-Host "Enter Azure subscription ID"
$ResourceGroup = Read-Host "Enter resource group name"
$Location = Read-Host "Enter Azure region (e.g. australiaeast, eastus)"
$Prefix = Read-Host "Enter resource name prefix (lowercase, no special chars)"
$AllowedIp = Read-Host "Enter your public IP for portal access (leave empty for fully private)"
$VmAdminUser = Read-Host "Enter jumpbox VM admin username (default: azureadmin)"
if (-not $VmAdminUser) { $VmAdminUser = "azureadmin" }
$VmAdminPass = Read-Host "Enter jumpbox VM admin password" -AsSecureString
$VmAdminPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($VmAdminPass))

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Yellow
Write-Host "Subscription:   $SubscriptionId"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Location:       $Location"
Write-Host "Prefix:         $Prefix"
Write-Host "Allowed IP:     $(if ($AllowedIp) { $AllowedIp } else { '(none - fully private)' })"
Write-Host "VM Admin User:  $VmAdminUser"
Write-Host "VM Admin Pass:  ********"
Write-Host "---------------" -ForegroundColor Yellow
Write-Host ""
$Confirm = Read-Host "Proceed with deployment? (y/n)"

if ($Confirm -notin @('y', 'Y')) {
    Write-Host "Deployment cancelled." -ForegroundColor Red
    exit 0
}

# Set subscription
az account set --subscription $SubscriptionId

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group '$ResourceGroup' exists in '$Location'..." -ForegroundColor Gray
az group create --name $ResourceGroup --location $Location --output none

# Deploy
Write-Host "Starting Bicep deployment..." -ForegroundColor Green
$deployParams = "prefix=$Prefix", "location=$Location", "vmAdminUsername=$VmAdminUser", "vmAdminPassword=$VmAdminPassPlain"
if ($AllowedIp) { $deployParams += "allowedIpAddress=$AllowedIp" }

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file infra/main.bicep `
    --parameters $deployParams `
    --output table

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
