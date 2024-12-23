# Description: Sync Azure AD group users with Databricks, preserving pre-existing users and adding specific exceptions.

# Check if the AzureAD module is installed
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Write-Host "AzureAD module not found. Installing now..." -ForegroundColor Yellow

    try {
        Install-Module -Name AzureAD -Force -AllowClobber -Scope CurrentUser
        Write-Host "AzureAD module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error installing AzureAD module: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "AzureAD module is already installed. Proceeding with authentication..." -ForegroundColor Green
}

Connect-AzureAD

# Variables
$databricksInstance = "https://adb-4137766740713707.7.azuredatabricks.net"
$accessGroups = @("Databricks-Group-Test") # Ensure this is an array
$scimToken = "dapi7dfcdd4d428ee30447dc02d5e17779d2-3"

# List of users to exclude from deletion
#In this part we will add all those users that have already been created in the databrick.
#It is important that the users are added because the script will compare the users found in the group with those created in the databrick and if they do not match it will delete the users from the databrick that are not found in the group, that is why this exception has been created.
$exceptionList = @(
    "mloncan@artech-consulting.com",
    "hcortes@artech-consulting.com"
    
    
)

# Headers for API
$headers = @{
    Authorization = "Bearer $scimToken"
    "Content-Type" = "application/json"
    Accept = "application/json"
}

# Function to fetch all Databricks users
function Get-DatabricksUsers {
    $users = @()
    $nextLink = "$databricksInstance/api/2.0/preview/scim/v2/Users"
    while ($nextLink) {
        try {
            $response = Invoke-RestMethod -Method Get -Uri $nextLink -Headers $headers
            $users += $response.Resources
            $nextLink = $response.Meta.'pagination.nextLink'
        } catch {
            Write-Host "Error fetching Databricks users: $_" -ForegroundColor Red
            break
        }
    }
    return $users
}

# Fetch all current Databricks users
$databricksUsers = Get-DatabricksUsers

# Loop through each group to synchronize users
foreach ($group in $accessGroups) {
    $groupname = Get-AzureADGroup -Filter "DisplayName eq '$group'"
    if ($groupname -eq $null) {
        Write-Host "Group '$group' not found in Azure AD." -ForegroundColor Yellow
        continue
    }

    # Fetch members of the Azure AD group
    $azureAdGroupUsers = Get-AzureADGroupMember -ObjectId $groupname.ObjectId
    $azureAdEmails = $azureAdGroupUsers | ForEach-Object { $_.UserPrincipalName }

    # Add new users to Databricks
    foreach ($user in $azureAdGroupUsers) {
        $userEmail = $user.UserPrincipalName
        $userGivenName = $user.GivenName
        $userSurname = $user.Surname

        # Check if user already exists in Databricks
        if ($databricksUsers | Where-Object { $_.emails[0].value -eq $userEmail }) {
            Write-Host "User $userEmail already exists in Databricks. Skipping..." -ForegroundColor Yellow
            continue
        }

        # Prepare the SCIM payload
        $userData = @{
            "schemas" = @("urn:ietf:params:scim:schemas:core:2.0:User")
            "userName" = $userEmail
            "name" = @{
                "givenName" = $userGivenName
                "familyName" = $userSurname
            }
            "emails" = @(@{"value" = $userEmail; "primary" = $true})
            "displayName" = $userEmail
            "active" = "true"
        } | ConvertTo-Json -Depth 10

        # Create user in Databricks
        $userApiUrl = "$databricksInstance/api/2.0/preview/scim/v2/Users"
        try {
            Invoke-RestMethod -Method Post -Uri $userApiUrl -Headers $headers -Body $userData
            Write-Host "User $userEmail added to Databricks." -ForegroundColor Green
        } catch {
            Write-Host "Failed to add user $userEmail to Databricks. Error:" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }

    # Remove users no longer in the group
    foreach ($databricksUser in $databricksUsers) {
        $databricksEmail = $databricksUser.emails[0].value

        # Check if user should be removed
        if (($databricksUser.displayName -eq $databricksEmail) -and 
            -not ($azureAdEmails -contains $databricksEmail) -and 
            -not ($exceptionList -contains $databricksEmail)) {
            Write-Host "Removing user $databricksEmail from Databricks..."

            # API URL for deleting user
            $deleteUserApiUrl = "$databricksInstance/api/2.0/preview/scim/v2/Users/$($databricksUser.id)"
            try {
                Invoke-RestMethod -Method Delete -Uri $deleteUserApiUrl -Headers $headers
                Write-Host "User $databricksEmail removed successfully." -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove user $databricksEmail. Error:" -ForegroundColor Red
                Write-Host $_.Exception.Message
            }
        }
    }
}

Write-Host "Sync operation completed." -ForegroundColor Green
