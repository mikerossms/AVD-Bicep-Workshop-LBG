<#
.SYNOPSIS
Just checks to make sure the necessary components are installed
#>
param (
    [Parameter(Mandatory)]
    [String]$username,
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af"
)

if (-not $username) {
    Write-Error "Please provide your username - e.g. 'initialCheck.ps1 -username jbloggs'"
    exit 1
}

#check to make sure that the "Connect-AzAccount" command is available and error if not
if (-not (Get-Command Connect-AzAccount -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: The Azure PowerShell module is not installed."
    exit 1
}

#Check that Connect-AzAccount is working by logging in.  Error if the login fails
if (-not (Connect-AzAccount -Subscription $subID)) {
    Write-Error "ERROR: Cannot log in to Azure"
    exit 1
}

#check that the subscription ID we are connected to matches the one we want and change it to the right one if not
Write-Host "Checking we are connected to the correct subscription (context)" -ForegroundColor Green
if ((Get-AzContext).Subscription.Id -ne $subID) {
    #they dont match so try and change the context
    Write-Warning "Changing context to subscription: $subID"
    $context = Set-AzContext -SubscriptionId $subID

    if ($context.Subscription.Id -ne $subID) {
        Write-Error "ERROR: Cannot change to subscription: $subID"
        exit 1
    }

    Write-Host "Changed context to subscription: $subID" -ForegroundColor Green
}

#Check to make sure that the LBG-AVD-Users AAD group exists
Write-Host "Checking that the user is a member of the LBG-AVD-Users AAD group" -ForegroundColor Green
$group = Get-AzADGroup -DisplayName "LBG-AVD-Users"
if (-not $group) {
    Write-Error "ERROR: Cannot find the LBG-AVD-Users AAD group"
    exit 1
}

#Get the details of the currently signed in user
$user = Get-AzADUser -SignedIn

#Check to make sure the username provided matches the one used to sign in
if ($user.UserPrincipalName -ne "$username@quberatron.com") {
    Write-Error "ERROR: The username provided does not match the one used to sign in"
    exit 1
}

#Get the members of the LBG-AVD-Users user group and determine if mike is a member
$members = Get-AzADGroupMember -ObjectId $group.id

# Check if a specific user is a member of the group
$groupUser = $members | Where-Object {$_.Id -eq $user.Id}

if (-not $groupUser) {
    Write-Error "User is not a member of the LBG-AVD-Users AAD group"
    exit 1
}

Write-Host "Checks and initial login complete" -ForegroundColor Green
