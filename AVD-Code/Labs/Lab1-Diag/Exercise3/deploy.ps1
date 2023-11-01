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
    [Parameter(Mandatory)]
    [String]$uniqueIdentifier,
    [String]$location = "uksouth",
    [String]$localEnv = "dev",
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [String]$workloadNameAVD = "avd",
    [String]$workloadNameDiag = "diag",
    [Bool]$dologin = $true,
    [Bool]$updateVault = $true
)

if (-not $uniqueIdentifier) {
    Write-Error "A unique identifier MUST be specified.  Always use the same identifier for EVERY deployment"
    exit 1
}


#Define the name of both the diagnostic and AVD deployment RG
$diagRGName = "rg-$workloadNameDiag-$location-$localEnv-$uniqueIdentifier"

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
$diagOutput = New-AzResourceGroupDeployment -Name "Deploy-Diagnostics" -ResourceGroupName $diagRGName -TemplateFile "$PSScriptRoot/../Bicep/Diagnostics/diagnostics.bicep" -Verbose -TemplateParameterObject @{
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



Write-Host "Finished Deployment" -ForegroundColor Green
