<#
    .SYNOPSIS
    This is an example script that is used by the Image Buidler (Packer) to install software into the image

    .DESCRIPTION
    This script provides a series of steps that calls on a set of common library functions to automate the
    building of a customised image.  This includes the installation of software of multiple types from
    multiple sources and direct configuration of the image as required

    It is called during the Image Builder build process, though it can also be called directly for testing.

    .INPUTS
    storageAccount - The name of the storage account that contains the software repository
    sasToken - The SAS token used to access the software repository
    container - The name of the container in the storage account that contains the software repository
    buildScriptsFolder - The folder that contains the common library functions (defaults to C:\BuildScripts)
    runLocally - If set to true, the script will run locally using the library functions relative to the folder structure in the GitHub repo
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$storageAccount,
    [Parameter(Mandatory=$true)]
    [string]$sasToken,
    [string]$container='repository',
    [string]$buildScriptsFolder='C:\BuildScripts',
    [Bool]$runLocally = $false
)

$InformationPreference = 'continue'

#Pull in the local library of functions
if ($runLocally) {
    import-module -Force "..\..\Components\BuildScriptsCommon\InstallSoftwareLibrary"
} else {
    import-module -Force "$PSScriptRoot\InstallSoftwareLibrary.psm1"
}

Write-Log "Running the Installer Script" -logtag "INSTALLER"

##Get the Repo Context - used to connect to the repo storage account (mandatory)
$repoContext = Get-RepoContext -storageRepoAccount $storageAccount -storageSASToken $sasToken -storageRepoContainer $container

######
# Everything below this point references the library functions to install software.  Take care in the order in which these are run to
# ensure that dependencies are met. For example, if you are installing a python PIP package, make sure that Python is already installed
######

##Install the multimedia extensions
Install-MSI -repoContext $repoContext -repoPath "MMRHostInstaller\MsMMRHostInstaller_x64.msi" -installParams ""

##Install the required tools:
Install-ChocoPackage -package "fxlogix"

##Install Software from Chocolatey
#Install core software and tools (choco repo package)
$chocoCoreTools = "LBG\ChocoLGBSoftwarePackages.config"
Install-ChocoPackageList -packageListPath $chocoCoreTools -repoContext $repoContext

##Copy the Sysprep Deprovisioning Script into place (this is required)
Write-Log "Copying Deprovisioning Script to C:\" -logtag $logtag
Copy-Item -Path "$buildScriptsFolder\DeprovisioningScript.ps1" -Destination "c:\DeprovisioningScript.ps1" -Force

Write-Log "Installation script finished" -logtag $logtag

