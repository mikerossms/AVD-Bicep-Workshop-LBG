<#
.SYNOPSIS
User defined script that uploads software from specifically defined local locations to the software container

.PARAMETER imageName
A mandatory variable for the name of the image that is being deployed.  This is the SAME name as the foler in "Images"
#>

param (
    [String]$repoName = "stlbibdevuksouth001",
    [String]$repoRG = "rg-lbgimagebuilder-dev-uksouth-001",
    [String]$repoContainerSoftware = "software",
    [String]$subscriptionID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [String]$rootFolder = "./Images/Common-FilesForSoftwareRepo",
    [Bool]$runAsPipeline = $true
)

#hash of software to upload - key is the local file path, value is the container name to put it
$software = @{
    "$rootFolder\LBG\ChocoLGBSoftwarePackages.config" = "LBG"
    "$rootFolder\MMRHostInstaller\MsMMRHostInstaller_x64.msi" = "MMRHostInstaller"
}

#Check we are in the right subscription
$subID = (Get-AzContext).Subscription.Id

if ($subID -ne $subscriptionID) {
    Write-Output "Switching to subscription: $subscriptionID"
    Set-AzContext -SubscriptionId $subscriptionID
}

#Check that the storage account container exists
Write-Output "Checking for Storage Account '$repoName' in '$repoRG'"
$stContainerContext = Get-AzStorageAccount -ResourceGroupName $repoRG -Name $repoName | Get-AzStorageContainer -Name $repoContainerSoftware
if (-Not $stContainerContext) {
    Write-Error "ERROR - Repo Storage Account / Container not found ($repoName / $repoContainerSoftware)"
    exit 1
}

#Upload the build scripts to the Repo storage account blob/buildscripts container
Write-Output "Uploading the Software to the Repository"

#Check to see if the image dependent folder exists locally
if (-not (Test-Path $rootFolder)) {
    Write-Error "ERROR: Could not find Root software folder.  Check path and try again"
    Write-Output " - Path: $rootFolder"
    exit 1
 }

#Step through $software and upload each file (key) to Azure blob container
foreach ($file in $software.GetEnumerator()) {
    $localFile = $file.Key
    $containerName = $file.Value

    #Check to see if the file exists locally
    if (-not (Test-Path $localFile)) {
        Write-Error "ERROR: Could not find local file.  Check path and try again"
        Write-Output " - Path: $localFile"
        exit 1
    }

    #Upload the file to the blob sub-container specifically for that image (to permit multiple images to be built at the same time)
    $uploadError = $null
    Write-Output "Uploading: $localFile to $repoName\$repoContainerSoftware\$containerName"
    
    #Get just the filename from the local file path
    $localFileNameOnly = $localFile.Split("\")[-1]

    $stContainerContext | Set-AzStorageBlobContent -File $localFile -Blob "$containerName\$localFileNameOnly" -Force -ErrorVariable uploadError

    if ($uploadError) {
        Write-Error "ERROR: There was an error uploading the build scripts to the repository.  Check the error and try again"
        Write-Output " - Error: $uploadError"
        exit 1
    }
}

Write-Output "Completed"
