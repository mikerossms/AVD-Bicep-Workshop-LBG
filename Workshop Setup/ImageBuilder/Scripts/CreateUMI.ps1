<#
.SYNOPSIS
Image Builder Setup - Create the UMI

.DESCRIPTION
This script will check for the existing of a UMI passed in as a parameter from the pipeline (or via command line) and checks if it exists.  If it
does not, then create it.

.PARAMETER umiName
The name of the UMI to check and create if it does not exist

.PARAMETER umiRG
The RG in which the UMI will exist or be created
#>

param (
    [String]$umiName = "umi-imagebuilder-prod-uksouth-001",
    [String]$umiRG,
    [String]$umiLocation,
    [String]$subscriptionID
)

#Check we are in the right subscription
$subID = (Get-AzContext).Subscription.Id

if ($subID -ne $subscriptionID) {
    Write-Output "Switching to subscription: $subscriptionID"
    Set-AzContext -SubscriptionId $subscriptionID
}

#check for the UMI existence
Write-Output "Checking for User Assigned Managed Identity '$umiName' in '$umiRG'"
$umiID = Get-AzUserAssignedIdentity -ResourceGroupName $umiRG -Name $umiName -ErrorAction SilentlyContinue

if (-Not $umiID) {
    Write-Output " - Creating missing User Assigned Managed Identity '$umiName'"
    $umiID = New-AzUserAssignedIdentity -ResourceGroupName $umiRG -Location $umiLocation -Name $umiName -SubscriptionID $subscriptionID  #-Tag $tags
    if ($umiID) {
        Write-Output " - Created '$umiName' ($($umiID.PrincipalId)) - pausing 60 seconds for Azure to catch up"
        Start-Sleep -s 60
    } else {
        Write-Output "FAILED to create '$umiName'"
        exit 1
    }
    
} else {
    Write-Output " - User Assigned Managed Identity '$umiName' already exists ($($umiID.PrincipalId))"
}

Write-Output "Completed"