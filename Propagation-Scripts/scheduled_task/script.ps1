[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$EndpointUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$EndpointPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [string]$ScheduledTaskName,

    [Parameter()]
    [ValidatePattern('^\\(?:[^\\]+\\)+\s*(?:,\s*\\(?:[^\\]+\\)+)*$')]
    [string]$ScheduledTaskPath
)

# Output the script parameters and the current user running the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]"

#region Functions
# Function to create a new PSCredential object
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}
#endregion

# Create a new PSCredential object using the provided EndpointUserName and EndpointPassword
$credential = newCredential $EndpointUserName $EndpointPassword

# Define a script block to be executed remotely on the Windows server
$scriptBlock = {

    #region functions
    # Function to decrypt a secure string password
    function decryptPassword {
        param(
            [securestring]$Password
        )
        try {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            ## Clear the decrypted password from memory
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }

    # Set the error action preference to stop execution if an error occurs
    $ErrorActionPreference = 'Stop'

    ## Assigning to variables inside the scriptblock allows mocking of args with Pester
    $username = $args[0]
    $pw = $args[1]
    $scheduledTaskNames = $args[2]
    $scheduledTaskPaths = $args[3]

    # Function to resolve an account name to its SID on this host, or $null when it cannot be resolved
    function resolveSid([string]$AccountName) {
        if (-not $AccountName) { return $null }
        try {
            (New-Object System.Security.Principal.NTAccount($AccountName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {
            $null
        }
    }

    # Each distinct task user is resolved once: a host has many tasks but few users, and on a domain-joined host
    # a name that cannot be resolved can wait on a domain controller.
    $sidCache = @{}

    # Function to check whether a task runs as the account. The task scheduler stores the user in several forms
    # (DOMAIN\user, user, user@domain.com, or a SID), so compare SIDs, and fall back to the names when one cannot be resolved.
    function isTaskAccount([string]$TaskUserId, [string]$AccountName, [string]$AccountSid) {
        if (-not $TaskUserId) { return $false }
        if ($TaskUserId -eq $AccountName) { return $true }
        if (-not $sidCache.ContainsKey($TaskUserId)) {
            $sidCache[$TaskUserId] = if ($TaskUserId -match '^S-1-') { $TaskUserId } else { resolveSid $TaskUserId }
        }
        $taskSid = $sidCache[$TaskUserId]
        $AccountSid -and $taskSid -and ($taskSid -eq $AccountSid)
    }
    #endregion

    #region Find all of the requested scheduled tasks
    $getSchedTaskParams = @{}
    if ($scheduledTaskNames) {
        $getSchedTaskParams.TaskName = $scheduledTaskNames
    }
    if ($scheduledTaskPaths) {
        $getSchedTaskParams.TaskPath = $scheduledTaskPaths
    }
    # Get scheduled tasks based on the provided task names and paths, and filter by the specified user
    $accountSid = resolveSid $username
    [array]$schedTasks = Get-ScheduledTask @getSchedTaskParams | Where-Object { isTaskAccount $_.Principal.UserId $username $accountSid }
    if (-not $schedTasks) {
        throw "No scheduled tasks found on [{0}] running as [{1}] could be found." -f (hostname), $username
    } elseif ($scheduledTaskNames -and ($notFoundScheduledTasks = $scheduledTaskNames.where({ $_ -notin $schedTasks.TaskName }))) {
        throw "The following scheduled tasks could not be found on host [{0}] running as [{1}]: {2}" -f (hostname), $username, ($notFoundScheduledTasks -join ',')
    }
    #endregion

    # Process each scheduled task and update the user password
    [array]$results = foreach ($schedTask in $schedTasks) {
        try {
            $null = Set-ScheduledTask -TaskName $schedTask.TaskName -TaskPath $schedTask.TaskPath -User $username -Password (decryptPassword($pw))
            $true
        } catch {
            if ($_.Exception.Message -match 'The user name or password is incorrect') {
                throw "NewPassword for [{0}] user account does not match provider for scheduled task [{1}] running on [{2}] host." -f $username, $schedTask.TaskName, (hostname)
            } else {
                throw $_
            }
        }
    }
    # Check if all scheduled tasks were successfully updated
    $results.Count -eq $schedTasks.Count
}

## To process multiple scheduled tasks at once. This approach must be done because DVLS will not allow you to pass an array
## of strings via a parameter.
## Entries are trimmed ("task1, task2" works) and empty entries are dropped.
$scheduledTaskNames = @($ScheduledTaskName -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$scheduledTaskPaths = @($ScheduledTaskPath -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# Define parameters for Invoke-Command
$invParams = @{
    ComputerName = $Endpoint
    ScriptBlock  = $scriptBlock
    Credential   = $credential
    ArgumentList = $AccountUserName, $NewPassword, $scheduledTaskNames, $scheduledTaskPaths
}
# Invoke the script block on the remote Windows server
Invoke-Command @invParams
