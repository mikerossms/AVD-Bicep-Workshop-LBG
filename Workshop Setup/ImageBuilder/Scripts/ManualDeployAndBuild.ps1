<#
.SYNOPSIS
Combines the cleanup, script upload and build image steps into a single script to run manually.

.NOTES
This is not for running in a pipeline!  For pipelines, use separate tasks.
#>

param (
    [Parameter(Mandatory)]
    [String]$imageName,
    [String]$subscriptionID,
    [String]$workloadName = "ImageBuilder",
    [String]$workloadNameShort = "IB",
    [String]$location = "uksouth",
    [String]$localenv = "dev",
    [String]$sequenceNum = "001",
    [int]$ibTimeout = 120,
    [string]$ibVMSize = "Standard_D2s_v3",
    [Bool]$dologin = $true,
    [Bool]$runBuild = $true,
    [bool]$uploadSoftware = $true

)

#If length of workloadNameShort is greater than 4, then error
if ($workloadNameShort.Length -gt 4) {
    Write-Error "Workload Short name is too long - maximum 4 characters"
    exit 1
}

if ($workloadNameShort.Length -le 0) {
    Write-Error "Workload Short name is too short - must be between 1 and 4 characters"
    exit 1
}

if ($env::System.JobId) {
    Write-Error "This script should not be run in a pipeline.  It is designed to run manually."
    exit 1
}

#Login to azure
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $subscriptionID
}

#Get the subsccription ID
$connectSubid = (Get-AzContext).Subscription.Id

#check that the subscription ID matchs that in the config
if ($connectSubid -ne $subscriptionID) {
    #they dont match so try and change the context
    Write-Host "Changing context to subscription: ($SubID)" -ForegroundColor Yellow
    $context = Set-AzContext -SubscriptionId $subscriptionID

    if ($context.Subscription.Id -ne $subscriptionID) {
        Write-Host "ERROR: Cannot change to subscription: ($subscriptionID)" -ForegroundColor Red
        exit 1
    }

    Write-Host "Changed context to subscription: ($subscriptionID)" -ForegroundColor Green
}

#Deploy the common infrastructure
$common = New-AzSubscriptionDeployment -Name "Common_Components" -Location $location -Verbose -TemplateFile "Bicep\common.bicep" -ErrorVariable defDeploy -TemplateParameterObject @{
    location=$location
    localenv=$localenv
    workloadName=$workloadName
    workloadNameShort=$workloadNameShort
    sequenceNum=$sequenceNum
}

$imageBuilderRG = $common.Outputs.imageBuilderRG.Value
$repoRG = $common.Outputs.storageRepoRG.Value
$repoName = $common.Outputs.storageRepoName.Value
$repoContainerScripts = $common.Outputs.storageRepoScriptsContainer.Value
$repoContainerSoftware = $common.Outputs.storageRepoSoftwareContainer.Value
$acgName = $common.Outputs.acgName.Value
$umiName = "umi-$workloadName-$localenv-$location-$sequenceNum".ToLower()

&.\Scripts\CreateUMI.ps1 -subscriptionID $subscriptionID -umiLocation $location -umiRG $repoRG -umiName $umiName
&.\Scripts\AssignUMI.ps1 `
    -subscriptionID $subscriptionID `
    -umiRG $repoRG `
    -umiName $umiName `
    -acgName $acgName `
    -acgRG $repoRG `
    -repoName $repoName `
    -repoRG $repoRG `
    -repoContainerScripts $repoContainerScripts `
    -repoContainerSoftware $repoContainerSoftware

Write-Host "Cleaning up templates" -ForegroundColor Green
&.\Scripts\CleanUpTemplates.ps1 -subscriptionID $subscriptionID -imageBuilderRG $imageBuilderRG -imageName $imageName

Write-Host "Uploading build scripts" -ForegroundColor Green
&.\Scripts\UploadBuildScripts.ps1 -subscriptionID $subscriptionID -repoRG $repoRG -repoName $repoName -repoContainerScripts $repoContainerScripts -imageName $imageName -runAsPipeline $false

if ($uploadSoftware) {
    Write-Host "Uploading Software" -ForegroundColor Green
    &.\Scripts\UploadSoftware.ps1 -subscriptionID $subscriptionID -repoRG $repoRG -repoName $repoName -repoContainerSoftware $repoContainerSoftware -rootFolder "./Images/Common-FilesForSoftwareRepo" -runAsPipeline $false
}

if ($runBuild) {
    Write-Host "Build Image" -ForegroundColor Green
    &.\Scripts\BuildImage.ps1 `
        -subscriptionID $subscriptionID `
        -imageRG $imageBuilderRG `
        -imageName $imageName `
        -ibTimeout $ibTimeout `
        -ibVMSize $ibVMSize `
        -doBuildImage $runBuild `
        -storageRepoName $repoName `
        -storageRepoRG $repoRG `
        -localenv $localenv `
        -location $location `
        -workloadName $workloadName `
        -workloadNameShort $workloadNameShort `
        -sequenceNum $sequenceNum `
        -publisher "Quberatron"
}



