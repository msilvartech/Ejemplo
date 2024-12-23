#------------------------------------ DO NOT CHANGE FROM HERE ----------------------------------------
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

# Loop through each user and assign variables
foreach ($user in $users) {
    # Create variables for SCIM
    $userDisplayName = $user.DisplayName
    $userEmail = $user.UserPrincipalName
    $userId = $user.ObjectId  # Azure AD User Object ID
    $userGivenName = $user.GivenName
    $userSurname = $user.Surname

    # Prepare the SCIM payload (this will depend on your SCIM schema)
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
            } | ConvertTo-Json

    # Display the user info (for testing)
    Write-Host "Creating user for $userDisplayName ($userEmail)"

    # API URL
$userApiUrl = "$databricksInstance/api/2.0/preview/scim/v2/Users"

    # Create user via POST request
try {
    $response = Invoke-RestMethod -Method Post -Uri $userApiUrl -Headers $headers -Body $userData
    Write-Host "User created successfully"
}
catch {
    Write-Host "Failed to create user. Error:"
    Write-Host $_.Exception.Message
    # Optional: Display more details if available
    if ($_.Exception.Response) {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $errorContent = $reader.ReadToEnd()
        Write-Host "Error response: $errorContent"} 
                                                     }
  }
}
#----------------------------------------- End of the script -----------------------------------------
