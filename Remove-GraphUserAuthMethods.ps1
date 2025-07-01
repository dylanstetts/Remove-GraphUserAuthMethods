# Remove-GraphUserAuthMethods.ps1
# This script removes legacy software OATH authentication methods from users in Microsoft Entra ID (Azure AD)
# using the Microsoft Graph PowerShell SDK. It supports dry-run mode, logs actions to a CSV, and handles throttling.

# Import the Microsoft Graph SDK root module (auto-loads submodules as needed)
# Import-Module Microsoft.Graph

# Connect to Microsoft Graph using delegated permissions
# Prompts the user to sign in with an account that has the necessary roles
Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.ReadWrite.All", "UserAuthenticationMethod.ReadWrite" 

# Prompt the user to choose dry-run mode
$dryRunInput = Read-Host "Do you want to run in dry-run mode? (yes/no)"
$dryRun = $dryRunInput -match "^(yes|y)$"

# Define the path for the audit log CSV
$logPath = "audit_log.csv"

# Number of retry attempts for throttling errors
$retryCount = 5

# Initialize the CSV file with headers
"UserPrincipalName,Action,MethodId,Status" | Out-File -FilePath $logPath

# Retrieve all users in the tenant
$users = Get-MgUser -All

# Loop through each user
foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    Write-Host "Checking user: $upn"

    # Initialize variable to hold authentication methods
    $methods = @()

    # Retry logic for throttling when retrieving authentication methods
    for ($i = 0; $i -lt $retryCount; $i++) {
        try {
            $methods = Get-MgUserAuthenticationMethod -UserId $user.Id
            break
        } catch {
            if ($_.Exception.Message -like "*429*") {
                $wait = [math]::Pow(2, $i)
                Write-Warning "Throttled while retrieving methods for $upn. Retrying in $wait seconds..."
                Start-Sleep -Seconds $wait
            } else {
                Write-Warning "Failed to retrieve methods for $upn : $($_.Exception.Message)"
                "$upn,RetrieveMethods,,Failed" | Out-File -Append $logPath
                continue
            }
        }
    }

    # Loop through each authentication method
    foreach ($method in $methods) {
        $odataType = $method.AdditionalProperties['@odata.type']
        # Check if the method is a legacy software OATH token
        if ($odataType -eq "#microsoft.graph.softwareOathAuthenticationMethod") {
            $methodId = $method.Id

            if ($dryRun) {
                # In dry-run mode, just log the action
                Write-Host "[Dry Run] Would remove method $methodId for $upn"
                "$upn,DryRun-RemoveMethod,$methodId,Preview" | Out-File -Append $logPath
            } else {
                # Attempt to remove the method with retry logic
                for ($j = 0; $j -lt $retryCount; $j++) {
                    try {
                        Remove-MgUserAuthenticationSoftwareOathMethod -UserId $user.Id -SoftwareOathAuthenticationMethodId $method.Id
                        Write-Host "Removed method $methodId for $upn"
                        "$upn,RemoveMethod,$methodId,Success" | Out-File -Append $logPath
                        break
                    } catch {
                        if ($_.Exception.Message -like "*429*") {
                            $wait = [math]::Pow(2, $j)
                            Write-Warning "Throttled while removing method $methodId for $upn. Retrying in $wait seconds..."
                            Start-Sleep -Seconds $wait
                        } else {
                            Write-Warning "Failed to remove method $methodId for $upn : $($_.Exception.Message)"
                            "$upn,RemoveMethod,$methodId,Failed" | Out-File -Append $logPath
                            break
                        }
                    }
                }
            }
        }
    }
}
