#-----------------------------------------------------------------------------------------------------
#                                     Databricks 1 | App: Example
#-----------------------------------------------------------------------------------------------------
# Variables
$databricksInstance = "https://adb-6234138917436195.15.azuredatabricks.net"
$accessGroups = "Databricks-Group-Test"
$scimToken = "token"
#------------------------------------ DO NOT CHANGE FROM HERE ----------------------------------------
$scriptDirectory = C:\home\site\wwwroot\
$exeScriptPath = Join-Path -Path $scriptDirectory -ChildPath "SCIM_API.ps1"
. $exeScriptPath
#----------------------------------------- End of the block  -----------------------------------------
#-----------------------------------------------------------------------------------------------------
