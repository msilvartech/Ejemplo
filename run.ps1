#-----------------------------------------------------------------------------------------------------
# Azure Function Timer Trigger Entry Point
#-----------------------------------------------------------------------------------------------------

# Function to handle script execution and logging
function Execute-Script {
    param (
        [string]$ScriptPath,
        [string]$Description
    )
    try {
        if (Test-Path $ScriptPath) {
            # Execute the script
            . $ScriptPath
            Write-Host "$Description script executed successfully" -ForegroundColor Green
        } else {
            Write-Host "$Description script not found at $ScriptPath" -ForegroundColor Yellow
        }
    } catch {
        # Log the error message
        Write-Error "Error executing $Description script: $_"
        throw
    }
}

# Get the current script's directory
$scriptDirectory = $PSScriptRoot

#-----------------------------------------------------------------------------------------------------
# Execute AD Authentication Script
#-----------------------------------------------------------------------------------------------------
$AD_AuthScriptPath = Join-Path -Path $scriptDirectory -ChildPath "AD_Auth.ps1"
Execute-Script -ScriptPath $AD_AuthScriptPath -Description "AD Authentication"

#-----------------------------------------------------------------------------------------------------
# Execute Databricks SCIM Management Script
#-----------------------------------------------------------------------------------------------------
$SCIMScriptPath = Join-Path -Path $scriptDirectory -ChildPath "DBR_conf.ps1"
Execute-Script -ScriptPath $SCIMScriptPath -Description "Databricks SCIM Management"

#-----------------------------------------------------------------------------------------------------
# Completion Message
#-----------------------------------------------------------------------------------------------------
Write-Host "All scripts executed. Timer Trigger run completed." -ForegroundColor Cyan
