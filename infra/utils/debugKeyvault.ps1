# ==================================================================================
# Azure Key Vault Troubleshooter
# Author: ChatGPT
# ==================================================================================

Clear-Host

$ResourceGroup = "alramz-dev-rg"
$KeyVault = "alramz-dev-key-vault"

function Pause-Script {
    Write-Host ""
    Read-Host "Press ENTER to continue"
}

function Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "          Azure Key Vault Troubleshooter"
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Resource Group : $ResourceGroup"
    Write-Host "Key Vault      : $KeyVault"
    Write-Host ""
}

function Check-Login {

    Header

    Write-Host "Checking Azure Login..." -ForegroundColor Yellow

    az account show --output table

    Pause-Script
}

function Check-Subscription {

    Header

    Write-Host "Current Subscription" -ForegroundColor Yellow

    az account show --output table

    Write-Host ""
    Write-Host "Available Subscriptions"
    az account list --output table

    Pause-Script
}

function Check-KeyVault {

    Header

    Write-Host "Key Vault Information" -ForegroundColor Yellow

    az keyvault show `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --output table

    Pause-Script
}

function Check-Provisioning {

    Header

    Write-Host "Provisioning State" -ForegroundColor Yellow

    az resource show `
        --resource-group $ResourceGroup `
        --resource-type Microsoft.KeyVault/vaults `
        --name $KeyVault `
        --query properties.provisioningState

    Pause-Script
}

function Check-RBAC {

    Header

    Write-Host "RBAC Mode" -ForegroundColor Yellow

    az keyvault show `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --query properties.enableRbacAuthorization

    Pause-Script
}

function Check-CurrentUser {

    Header

    Write-Host "Current Azure User" -ForegroundColor Yellow

    az ad signed-in-user show `
        --query "{Name:displayName,ObjectId:id,UPN:userPrincipalName}" `
        --output table

    Pause-Script
}

function Check-Roles {

    Header

    $kvId = az keyvault show `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --query id `
        -o tsv

    $userId = az ad signed-in-user show `
        --query id `
        -o tsv

    Write-Host "Current User Role Assignments" -ForegroundColor Yellow

    az role assignment list `
        --assignee $userId `
        --scope $kvId `
        --output table

    Pause-Script
}

function Check-Firewall {

    Header

    Write-Host "Network ACLs" -ForegroundColor Yellow

    az keyvault show `
        --name $KeyVault `
        --query properties.networkAcls

    Pause-Script
}

function Check-PrivateEndpoint {

    Header

    Write-Host "Private Endpoints" -ForegroundColor Yellow

    az network private-endpoint list `
        --resource-group $ResourceGroup `
        --output table

    Pause-Script
}

function Test-Secret {

    Header

    Write-Host "Testing Secret Creation..." -ForegroundColor Yellow

    az keyvault secret set `
        --vault-name $KeyVault `
        --name TestSecret `
        --value "Test123!"

    Pause-Script
}

function Debug-Secret {

    Header

    Write-Host "Testing Secret Creation (Debug Mode)" -ForegroundColor Yellow

    az keyvault secret set `
        --vault-name $KeyVault `
        --name TestSecret `
        --value "Test123!" `
        --debug

    Pause-Script
}

function Assign-SecretsOfficer {

    Header

    $kvId = az keyvault show `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --query id `
        -o tsv

    $userId = az ad signed-in-user show `
        --query id `
        -o tsv

    Write-Host "Assigning Key Vault Secrets Officer..." -ForegroundColor Yellow

    az role assignment create `
        --assignee $userId `
        --role "Key Vault Secrets Officer" `
        --scope $kvId

    Pause-Script
}

function Run-AllChecks {

    Header

    Write-Host "============================="
    Write-Host "Current User"
    Write-Host "============================="

    az ad signed-in-user show `
        --query "{Name:displayName,ObjectId:id,UPN:userPrincipalName}" `
        --output table

    Write-Host ""

    Write-Host "============================="
    Write-Host "Key Vault"
    Write-Host "============================="

    az keyvault show `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --query "{Name:name,RBAC:properties.enableRbacAuthorization,Location:location}"

    Write-Host ""

    Write-Host "============================="
    Write-Host "Provisioning State"
    Write-Host "============================="

    az resource show `
        --resource-group $ResourceGroup `
        --resource-type Microsoft.KeyVault/vaults `
        --name $KeyVault `
        --query properties.provisioningState

    Write-Host ""

    $kvId = az keyvault show `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --query id `
        -o tsv

    $userId = az ad signed-in-user show `
        --query id `
        -o tsv

    Write-Host "============================="
    Write-Host "Role Assignments"
    Write-Host "============================="

    az role assignment list `
        --assignee $userId `
        --scope $kvId `
        --output table

    Write-Host ""

    Write-Host "============================="
    Write-Host "Firewall"
    Write-Host "============================="

    az keyvault show `
        --name $KeyVault `
        --query properties.networkAcls

    Pause-Script
}

do {

    Header

    Write-Host "1  - Check Azure Login"
    Write-Host "2  - Check Subscription"
    Write-Host "3  - View Key Vault"
    Write-Host "4  - Check Provisioning State"
    Write-Host "5  - Check RBAC Mode"
    Write-Host "6  - Show Current User"
    Write-Host "7  - Check Role Assignments"
    Write-Host "8  - Check Firewall"
    Write-Host "9  - Check Private Endpoint"
    Write-Host "10 - Test Secret Creation"
    Write-Host "11 - Test Secret (Debug)"
    Write-Host "12 - Assign Key Vault Secrets Officer"
    Write-Host "13 - Run Complete Health Check"
    Write-Host "0  - Exit"
    Write-Host ""

    $choice = Read-Host "Select Option"

    switch ($choice) {

        "1" { Check-Login }
        "2" { Check-Subscription }
        "3" { Check-KeyVault }
        "4" { Check-Provisioning }
        "5" { Check-RBAC }
        "6" { Check-CurrentUser }
        "7" { Check-Roles }
        "8" { Check-Firewall }
        "9" { Check-PrivateEndpoint }
        "10" { Test-Secret }
        "11" { Debug-Secret }
        "12" { Assign-SecretsOfficer }
        "13" { Run-AllChecks }
        "0" { break }

        default {
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }

} while ($true)

<# ##################################
$kvId = az keyvault show `
    --name "alramz-dev-key-vault" `
    --resource-group "alramz-dev-rg" `
    --query id `
    -o tsv

$userId = az ad signed-in-user show `
    --query id `
    -o tsv

az role assignment list `
    --assignee $userId `
    --scope $kvId `
    --output table

az role assignment list `
    --assignee $userId `
    --all `
    --output table

az role assignment create `
    --assignee $userId `
    --role "Key Vault Secrets Officer" `
    --scope $kvId

az role assignment create `
    --assignee $userId `
    --role "Key Vault Administrator" `
    --scope $kvId

#>