# Variables
$databricksInstance = "https://example.azuredatabricks.net"
$accessGroups = "Databricks-Group-Test"
$scimToken = "token"
$exceptionList = @("admin@yourdomain.com") # Add any users to exclude from removal

# Headers
$headers = @{
    Authorization = "Bearer $scimToken"
    "Content-Type" = "application/json"
    Accept = "application/json"
}

# Loop through each group and retrieve users
foreach ($group in $accessGroups) {
    $groupname = Get-AzureADGroup -Filter "DisplayName eq '$group'"
    $users = Get-AzureADGroupMember -ObjectId $groupname.ObjectId

    # Fetch all Databricks users
    $databricksUsersApiUrl = "$databricksInstance/api/2.0/preview/scim/v2/Users"
    $databricksUsers = @()
    $nextLink = $databricksUsersApiUrl
    while ($nextLink) {
        $response = Invoke-RestMethod -Method Get -Uri $nextLink -Headers $headers
        $databricksUsers += $response.Resources
        $nextLink = if ($response.Meta.pagination?.nextLink) { $response.Meta.pagination.nextLink } else { $null }
    }

    # Build a list of current Azure AD group users
    $azureAdUsers = @{}
    foreach ($user in $users) {
        $azureAdUsers[$user.UserPrincipalName] = $true
    }

    # Compare and remove users from Databricks not in Azure AD group or exception list
    foreach ($databricksUser in $databricksUsers) {
        $databricksUserEmail = $databricksUser.emails[0].value
        if (-not $azureAdUsers.ContainsKey($databricksUserEmail) -and -not ($exceptionList -contains $databricksUserEmail)) {
            Write-Host "Removing user: $databricksUserEmail"
            
            # API URL for deleting a user
            $deleteUserApiUrl = "$databricksInstance/api/2.0/preview/scim/v2/Users/$($databricksUser.id)"
            try {
                Invoke-RestMethod -Method Delete -Uri $deleteUserApiUrl -Headers $headers
                Write-Host "User $databricksUserEmail removed successfully." -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove user $databricksUserEmail. Error:" -ForegroundColor Red
                Write-Host $_.Exception.Message
            }
        }
    }
}
