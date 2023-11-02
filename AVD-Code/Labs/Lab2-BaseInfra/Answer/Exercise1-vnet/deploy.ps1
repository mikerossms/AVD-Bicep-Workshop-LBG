<#
.SYNOPSIS
Deploys the bicep code to the subscription.

.DESCRIPTION
This script deploys all the required code necessary in order to deploy the fully working AVD.  this includes:
- Diagnostics
- Infrastructure
- Hosts

It is also responsible for adding a user to the Application Group and changing the name of the remote desktop.
#>

#Get the runtime parameters from the user.  You will need to change the "uniqueIdentifier" for each user to avoid clashes
param (
    [String]$uniqueIdentifier = "",
    [String]$location = "uksouth",
    [String]$localEnv = "dev",
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [String]$workloadNameAVD = "lbg",
    [String]$workloadNameDiag = "lbg",
    [String]$avdVnetCIDR = "",
    [Bool]$dologin = $false
)

if (-not $uniqueIdentifier) {
    Write-Error "A unique identifier MUST be specified.  Always use the same identifier for EVERY deployment"
    exit 1
}

if (-not $avdVnetCIDR) {
    Write-Error "You must specify a virtual network address range in CIDR format.  You will be provided this by the instructor"
    exit 1
}

#Define the name of both the diagnostic and AVD deployment RG
$avdRGName = "rg-$workloadNameAVD-$location-$localEnv-$uniqueIdentifier"
$diagRGName = "rg-$workloadNameDiag-$location-$localEnv-$uniqueIdentifier"

#Configure the networking for this instance of AVD.
#$avdVnetCIDR = "10.200.1.0/24" - now set in the parameters
$avdSnetCIDR = $avdVnetCIDR

#Configure the DNS servers to use for this service - These are static and point to the already deployed Entra DS, so will not need to change
$adServerIPAddresses = @(
  '10.99.99.4'
  '10.99.99.5'
)

#Set up some basic tags to attach to resources
$tags = @{
    Environment=$localEnv
    Owner="LBG"
}

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

#Create a resource group for the diagnostic resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $diagRGName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $diagRGName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $diagRGName -Location $location)) {
        Write-Error "ERROR: Cannot create Resource Group: $diagRGName"
        exit 1
    }
}

#Deploy the diagnostic.bicep code to that RG we just created
Write-Host "Deploying diagnostic.bicep to Resource Group: $diagRGName" -ForegroundColor Green
$diagOutput = New-AzResourceGroupDeployment -Name "Deploy-Diagnostics" -ResourceGroupName $diagRGName -TemplateFile "$PSScriptRoot/Bicep/Diagnostics/diagnostics.bicep" -Verbose -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    tags=$tags
    workloadName=$workloadNameDiag
    uniqueName=$uniqueIdentifier
}

if (-not $diagOutput ) {
    Write-Error "ERROR: Cannot deploy diagnostic.bicep to Resource Group: $diagRGName"
    exit 1
}


#Create a resource group for the AVD resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $avdRGName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $avdRGName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $avdRGName -Location $location)) {
        Write-Error "ERROR: Cannot create Resource Group: $avdRGName"
        exit 1
    }
}

#Deploy the AVD backplane bicep code which includes the networks, keyvault, hostpool, app grup and worspace.
#the user deploying this script is also then added to the App Group as a user
Write-Host "Deploying Infrastructure (backplane.bicep) to Resource Group: $avdRGName" -ForegroundColor Green
$backplaneOutput = New-AzResourceGroupDeployment -Name "Deploy-Backplane" `
 -ResourceGroupName $avdRGName `
 -TemplateFile "$PSScriptRoot/Bicep/Infrastructure/backplane.bicep" `
 -Verbose `
 -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    uniqueName=$uniqueIdentifier
    tags=$tags
    workloadName=$workloadNameAVD
    rgDiagName=$diagRGName
    lawName=$diagOutput.Outputs.lawName.Value
    avdVnetCIDR=$avdVnetCIDR
    avdSnetCIDR=$avdSnetCIDR
    adServerIPAddresses=$adServerIPAddresses
}

if (-not $backplaneOutput.Outputs.subNetId.Value) {
    Write-Error "ERROR: Failed to deploy BackPlane to Resource Group: $avdRGName"
    exit 1
}

#finished
Write-Host "Finished Deployment" -ForegroundColor Green