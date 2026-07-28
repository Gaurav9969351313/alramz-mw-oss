# ============================================================================
# Configuration
# ============================================================================

$SubscriptionId = "9b9d81dc-3f06-48b2-b936-0a6b805fe94e"
$ResourceGroup  = "alramz-dev-rg"
$ApimName       = "alramz-dev-api-gateway"
$ApiId          = "data-validation-api"          # API identifier in APIM (not display name)
$Gateway        = "managed"

$SubscriptionKey = "8e4adf58b31146e28f0dd442abaa13ff"

# Your API URL
$ApiUrl = "https://alramz-dev-api-gateway.azure-api.net/validation/api/v1/info"

# ============================================================================
# Get Azure Management Token
# ============================================================================

Write-Host "Getting Azure access token..."

$AccessToken = az account get-access-token `
    --resource https://management.azure.com `
    --query accessToken `
    -o tsv

if (-not $AccessToken) {
    throw "Unable to obtain Azure access token."
}

# ============================================================================
# Get API Resource ID
# ============================================================================

Write-Host "Getting API Resource ID..."

$ApiResourceId = az apim api show `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --query id `
    -o tsv

Write-Host "API Resource ID:"
Write-Host $ApiResourceId

# ============================================================================
# Request Debug Token
# ============================================================================

Write-Host "Requesting APIM debug token..."

$Body = @{
    credentialsExpireAfter = "PT1H"
    apiId                  = $ApiResourceId
    purposes               = @("tracing")
} | ConvertTo-Json

$DebugTokenResponse = Invoke-RestMethod `
    -Method POST `
    -Uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/gateways/$Gateway/listDebugCredentials?api-version=2023-05-01-preview" `
    -Headers @{
        Authorization = "Bearer $AccessToken"
    } `
    -ContentType "application/json" `
    -Body $Body

$DebugToken = $DebugTokenResponse.token
Write-Host $DebugToken
Write-Host "Debug token acquired."

# ============================================================================
# Call API
# ============================================================================

Write-Host "Calling API..."

$response = Invoke-WebRequest `
    -Uri $ApiUrl `
    -Method GET `
    -Headers @{
        "Ocp-Apim-Subscription-Key" = $SubscriptionKey
        "Apim-Debug-Authorization"  = $DebugToken
    }

$TraceId = $response.Headers["Apim-Trace-Id"]

Write-Host "HTTP Status: $($response.StatusCode)"
Write-Host "Trace ID: $TraceId"

if (-not $TraceId) {
    throw "No Apim-Trace-Id returned."
}

# ============================================================================
# Download Trace
# ============================================================================

Write-Host "Downloading trace..."

$TraceBody = @{
    traceId = $TraceId
} | ConvertTo-Json

$Trace = Invoke-RestMethod `
    -Method POST `
    -Uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/gateways/$Gateway/listTrace?api-version=2023-05-01-preview" `
    -Headers @{
        Authorization = "Bearer $AccessToken"
    } `
    -ContentType "application/json" `
    -Body $TraceBody

# Save trace
$Trace | ConvertTo-Json -Depth 100 | Out-File ".\apim-trace.json"

Write-Host ""
Write-Host "=========================================="
Write-Host "Trace downloaded successfully."
Write-Host "Saved to: .\apim-trace.json"
Write-Host "=========================================="
