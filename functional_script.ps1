


#***************************************************************
#*************************************************************




# Description: Sync Azure AD group users with Databricks, preserving pre-existing users and adding specific exceptions.

# Check if the AzureAD module is installed
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

$workspaceUrl = "https://adb-1777639999844358.18.azuredatabricks.net"
$groupIdAzureAD = "fd9e855b-2ed4-4210-ad52-3c90c94b28e7"  # Group ID in Azure AD
$token = "dapi7a7d0f9e564028971117890a53544ba6-3"  # Databricks token
 

# Headers for API
$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
    Accept = "application/json"
}

# Get group members in Azure AD
Write-Host “Getting users from Azure AD...”
$azureAdUsers = Get-AzureADGroupMember -ObjectId $groupIdAzureAD | Select-Object -ExpandProperty UserPrincipalName

# Define Databricks groups
$databricksGroups = @(
    @{ Name = "GDSG-AD-Test-Group"; Id = "645976437602782" },
    @{ Name = "test_local_group"; Id = "114154106815762" }
)

# Menu to select Databricks group
Write-Host "Select the Databricks group to which you want to add and remove users:"
for ($i = 0; $i -lt $databricksGroups.Length; $i++) {
    Write-Host "$($i + 1). $($databricksGroups[$i].Name)"
}
$selection = Read-Host "Enter the group number"

# Validate selection
if ($selection -gt 0 -and $selection -le $databricksGroups.Length) {
    $selectedGroup = $databricksGroups[$selection - 1]
    Write-Host "Databricks group selected: $($selectedGroup.Name)"
} else {
    Write-Host "Invalid selection. Exiting script." -ForegroundColor Red
    exit 1
}

# Get current users of selected group in Databricks
Write-Host "Getting users from group $($selectedGroup.Name) in Databricks..."
$apiEndpointDatabricks = "$workspaceUrl/api/2.0/preview/scim/v2/Groups/$($selectedGroup.Id)"
$response = Invoke-RestMethod -Method Get -Uri $apiEndpointDatabricks -Headers $headers

# Extract IDs of current group members in Databricks
$databricksUsers = @()
if ($response.members) {
    $databricksUsers = $response.members | ForEach-Object { $_.value }
}

# Validate if group is a Workspace group
$scimToken = "dapi87a588e2cb9df486ead78ceb1f052227-3"
$apiUrl = "https://adb-2438127445875997.17.azuredatabricks.net/api/2.0/preview/scim/v2/Groups"
$responseGroups = Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $scimToken"} -Method Get
$responseGroups | ConvertTo-Json -Depth 10

$groupSource = ($responseGroups.Resources | Where-Object { $_.id -eq $selectedGroup.Id }).source

#Variable for tracking errors
$errorOccurred = $false

# Add only users that are not in Databricks
foreach ($userEmail in $azureAdUsers) {
    # Get User ID in Databricks
    $userApiUrl = "$workspaceUrl/api/2.0/preview/scim/v2/Users"
    $userResponse = Invoke-RestMethod -Method Get -Uri $userApiUrl -Headers $headers
    $databricksUser = $userResponse.Resources | Where-Object { $_.userName -eq $userEmail }

    if ($databricksUser) {
        $userId = $databricksUser.id

        # Check if the user is already in the group
        if ($databricksUsers -contains $userId) {
            Write-Host "User $userEmail is already in the Databricks group. Omitting..." -ForegroundColor Yellow
            continue
        }

        # Add user to the group in Databricks
        Write-Host "Adding user $userEmail ($userId) to Databricks..."
        $requestBody = @{
            schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = @(
                @{
                    op    = "add"
                    value = @{
                        members = @(@{ value = $userId })
                    }
                }
            )
        } | ConvertTo-Json -Depth 10

        try {
            Invoke-RestMethod -Uri $apiEndpointDatabricks -Method Patch -Headers $headers -Body $requestBody -ContentType "application/json"
            Write-Host "********************88User $userEmail added successfully***********************." -ForegroundColor Green
        } catch {
            $errorOccurred = $true
            $grupoNombre = $selectedGroup.Name  # Name of the selected group

            if ($_.Exception.Response.StatusCode -eq 500 -or $_.Exception.Response.StatusCode -eq 400) {
                $errorMessage =  “Error adding users to group $grupoNombre, only users with permissions in the Databricks console can add users to this group, please address with your manager or IT manager.”
                if ($groupSource -ne "Workspace") {
                    $errorMessage += “The group is not a workspace type.”
                }
                Write-Host $errorMessage -ForegroundColor Red
            } else {
                Write-Host "Error adding user  $userEmail to grup $grupoNombre. Error:" -ForegroundColor Red
                Write-Host $_.Exception.Message
            }
        }
    } else {
        # Create the user in Databricks if it does not exist
        Write-Host "User $userEmail not found in Databricks. Creating user..."
        $createUserBody = @{
            schemas = @("urn:ietf:params:scim:schemas:core:2.0:User")
            userName = $userEmail
            emails = @(@{ value = $userEmail })
        } | ConvertTo-Json -Depth 10

        try {
            $newUserResponse = Invoke-RestMethod -Uri $userApiUrl -Method Post -Headers $headers -Body $createUserBody -ContentType "application/json"
            $newUserId = $newUserResponse.id

            # Add the new user to the group in Databricks
            Write-Host "Adding user $userEmail ($newUserId) to group $($selectedGroup.Name)..."
            $requestBody = @{
                schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
                Operations = @(
                    @{
                        op    = "add"
                        value = @{
                            members = @(@{ value = $newUserId })
                        }
                    }
                )
            } | ConvertTo-Json -Depth 10

            Invoke-RestMethod -Uri $apiEndpointDatabricks -Method Patch -Headers $headers -Body $requestBody -ContentType "application/json"
            Write-Host "Usuer $userEmail successfully added to group $($selectedGroup.Name)." -ForegroundColor Green
        } catch {
            $errorOccurred = $true
            Write-Host "Error creating or adding user $userEmail to group $($selectedGroup.Name). Error:" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }
}

# Display final message based on whether there were errors or not
if ($errorOccurred) {
    Write-Host "***********************************Synchronization failed****************************************." -ForegroundColor Cyan
} else {
    Write-Host "********************************Synchronization completed***************************************." -ForegroundColor Cyan
}
