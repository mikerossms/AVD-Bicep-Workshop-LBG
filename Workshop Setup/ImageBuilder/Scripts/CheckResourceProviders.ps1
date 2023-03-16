<#
.SYNOPSIS
Check to see if the required providers are registered in the subscription and attempts to register them if not
#>

param (
    [Parameter(Mandatory)]
    [String]$subscriptionID
)

#Check we are in the right subscription
$subID = (Get-AzContext).Subscription.Id

if ($subID -ne $subscriptionID) {
    Write-Output "Switching to subscription: $subscriptionID"
    Set-AzContext -SubscriptionId $subscriptionID
}

$requiredProviders = @(
    "Microsoft.ManagedIdentity"
    "Microsoft.KeyVault"
    "Microsoft.DesktopVirtualization"
    "Microsoft.VirtualMachineImages"
    "Microsoft.Storage"
)

foreach ($provider in $requiredProviders) {
    Write-Output "Checking for Azure Resource Provider '$provider'"
    $pExist = (Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState[0]
    if ($pExist -eq "NotRegistered") {
        Write-Output "Registering Azure Resource Provider '$provider'"
        Register-AzResourceProvider -ProviderNamespace $provider
    }
}

