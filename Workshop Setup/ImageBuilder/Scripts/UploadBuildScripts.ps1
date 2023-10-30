<#
.SYNOPSIS
Pulls the build scripts together into a single Zip and uploads it to the Build Scripts container in the storage repo

.DESCRIPTION
This will pull together the following files:
- Components/ImageBuilderCommonScripts/InstallSoftwareLibrary.psm1
- Components/ImageBuilderCommonScripts/DeprovisioningScript.ps1
- Images/<desktop>/InstallSoftware.ps1
- Images/<desktop>/ValidateEnvironment.ps1

Into a zip file called buildscripts.zip and uploads that file to the buildscripts container in the software repo

.PARAMETER imageName
A mandatory variable for the name of the image that is being deployed.  This is the SAME name as the foler in "Images"
#>

param (
    [Parameter(Mandatory)]
    [String]$imageName,
    [String]$repoName = "stibproduksouth001",
    [String]$repoRG = "rg-imagebuilder-prod-uksouth-001",
    [String]$repoContainerScripts = "buildscripts",
    [String]$subscriptionID = "f258c6c4-0a76-40eb-b002-b20a8fde7d70",
    [Bool]$runAsPipeline = $true
)

$imageDepScriptFolder = ".\Images\$imageName"
$imageCommonScriptFolder = ".\Components\ImageBuilderCommonScripts"
$imageBuildScriptsZipName = "buildscripts.zip"

if (-Not $runAsPipeline) {
    $imageDepScriptFolder = ".\Images\$imageName"
    $imageCommonScriptFolder = ".\Components\ImageBuilderCommonScripts"
}

#Check we are in the right subscription
$subID = (Get-AzContext).Subscription.Id

if ($subID -ne $subscriptionID) {
    Write-Output "Switching to subscription: $subscriptionID"
    Set-AzContext -SubscriptionId $subscriptionID
}

#Check that the storage account container exists
Write-Output "Checking for Storage Account '$repoName' in '$repoRG'"
$stContainerContext = Get-AzStorageAccount -ResourceGroupName $repoRG -Name $repoName | Get-AzStorageContainer -Name $repoContainerScripts
if (-Not $stContainerContext) {
    Write-Error "ERROR - Repo Storage Account / Container not found ($repoName / $repoContainerScripts)"
    exit 1
}

#Upload the build scripts to the Repo storage account blob/buildscripts container
Write-Output "Uploading the Build Scripts to the Repository"

#Check to see if the image dependent folder exists locally
if (-not (Test-Path $imageDepScriptFolder)) {
    Write-Error "ERROR: Could not find Image folder - build scripts are required for deployment.  Check path and try again"
    Write-Output " - Path: $imageDepScriptFolder"
    exit 1
 }

#Check to see if the common/shared build Scripts folder exists locally
if (-not (Test-Path $imageCommonScriptFolder)) {
    Write-Error "ERROR: Could not find the common/shared build scripts folder - build scripts are required for deployment.  Check path and try again"
    Write-Output " - Path: $imageCommonScriptFolder"
    exit 1
 }

#Pull all the files together into a single zip file
Write-Host " - Pulling files together into a single Zip file for upload"
$compressError = $null
$compress = @{
    Path = "$imageDepScriptFolder\\*.ps1", "$imageCommonScriptFolder\\*"
    CompressionLevel = 'Fastest'
    DestinationPath = "$($env:TEMP)\\$imageBuildScriptsZipName"
    Force = $true
}
Compress-Archive @compress -ErrorVariable compressError
if ($compressError) {
    Write-Error "ERROR: There was an error compressing the build scripts.  Check the error"
    Write-Output " - Error: $($compressError[0].Exception.Message)"
    exit 1
}

#Check to see if the new zip file exists
if (-not (Test-Path "$($env:TEMP)\$imageBuildScriptsZipName")) {
    Write-Error "ERROR: Could not find the new zip file - build scripts are required for deployment.  Check the output from the file compression"
    Write-Output " - Path: $($env:TEMP)\$imageBuildScriptsZipName"
    exit 1
}

#Upload the zip file to the blob sub-container specifically for that image (to permit multiple images to be built at the same time)
$uploadError = $null
Write-Output "Uploading: $($env:TEMP)\$imageBuildScriptsZipName to $repoName\$repoContainerScripts\$imageName"
$stContainerContext | Set-AzStorageBlobContent -File "$($env:TEMP)\$imageBuildScriptsZipName" -Blob "$imageName\$imageBuildScriptsZipName" -Force -ErrorVariable uploadError

if ($uploadError) {
    Write-Error "ERROR: There was an error uploading the build scripts to the repository.  Check the error and try again"
    Write-Output " - Error: $uploadError"
    exit 1
}

Write-Output "Completed"
