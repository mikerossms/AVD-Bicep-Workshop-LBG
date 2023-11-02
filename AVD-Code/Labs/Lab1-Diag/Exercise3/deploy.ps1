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
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [String]$location = "uksouth",
    [String]$localEnv = "dev",
    [String]$workloadNameDiag = "lbg",
    [Bool]$dologin = $false
)

if (-not $uniqueIdentifier) {
    Write-Error "Please provide your Unique Identifier - e.g. 'deploy.ps1 -uniqueIdentifier jbloggs'"
    exit 1
}

#Login to azure (if required) - if you have already done this once, then it is unlikley you will need to do it again for the remainer of the session
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $subID
} else {
    Write-Warning "Login skipped"
}

#Create the resource group name from the unique identifier
$diagRGName = "rg-$workloadNameDiag-$location-$localEnv-$uniqueIdentifier"

#Set up some basic tags to attach to resources
$tags = @{
    Environment=$localEnv
    Owner="LBG"
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

#Create the resource group if it does not already exist
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

Write-Host "The diagnostics.bicep returned:"
Write-Host "lawName: $($diagOutput.Outputs.lawName)"
Write-Host "lawID: $($diagOutput.Outputs.lawID)"

Write-Host "Finished Deployment" -ForegroundColor Green
