<#
This script deploys the Hub Vnet with a local firewall.  this is used to act as a Router to allow each users vnet to talk to each other
and each of the vnets to talk to the Entra Domain Services vnet.
#>

param (
    [String]$subID = '152aa2a3-2d82-4724-b4d5-639edab485af',
    [String]$workloadName = "LBGCentralHub",
    [String]$location = "uksouth",
    [String]$localenv = "dev",
    [String]$sequenceNum = "001",
    [Bool]$dologin = $true
)

#Login to azure (if required) - if you have already done this once, then it is unlikley you will need to do it again for the remainer of the session
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $subID
} else {
    Write-Warning "Login skipped"
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

#Deploy the hub.bicep to build out the central hub
Write-Host "Deploying the Hub Services" -ForegroundColor Green
$rg = "rg-$workloadName-$localenv-$location-$sequenceNum".ToLower()

#Check if the resource group exists, if not then create it
write-host "Checking if resource group: $rg exists" -ForegroundColor Green
if (!(Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group: $rg" -ForegroundColor Green
    New-AzResourceGroup -Name $rg -Location $location
} else {
    Write-Host "Resource group: $rg already exists" -ForegroundColor Green
}

Write-Host "Deploying the Hub Services" -ForegroundColor Green
New-AzResourceGroupDeployment -Name "Deploy-Hub" -ResourceGroupName $rg -TemplateFile "./hub.bicep" -Verbose -TemplateParameterObject @{
    location=$location
    localenv=$localenv
    workloadName=$workloadName
    sequenceNum=$sequenceNum
}