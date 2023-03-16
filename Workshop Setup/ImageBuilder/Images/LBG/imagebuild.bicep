//Define and deploy and image to the Compute Gallery using Image Builder

targetScope = 'subscription'

//Parameters
@description('The local environment identifier.  Default: prod')
param localenv string = 'prod'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@maxLength(4)
@description('Workload short code (max 4 chars)')
param workloadNameShort string = 'IB'

@description('Workload short code (max 4 chars)')
param workloadName string = 'ImageBuilder'

@description('The Publisher name for the Image')
param publisher string = 'AVDSquad'

@description('The sequence number of the resource e.g. 001')
param sequenceNumber string = '001'

@description('Creation date of the resources in UTC format')
param nowDate string = utcNow('yyyy-MM-dd HH:mm:mmZ')

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  WorkloadName: workloadName
  BusinessCriticality: 'medium'
  CostCentre: 'csu'
  Owner: 'AVD Squad'
  DataClassification: 'general'
  Updated: nowDate
}

@description('The name of the storage account to create as a software repo for the Image Builder and a place to host its common components')
param storageRepoName string = toLower('st${workloadNameShort}${localenv}${location}${sequenceNumber}')  //Storage names are alphanumeric only

@description('The name of the RG where the storage repository is found')
param storageRepoRG string = toLower('rg-${workloadName}-${localenv}-${location}-${sequenceNumber}')

@description('The name of the container to hold the scripts used to build the Image Builder')
param containerIBScripts string = 'buildscripts'

@description('The name of the container to hold the software to be installed by the Image Builder')
param containerIBSoftware string = 'software'

@description('The Name of the compute gallery')
param computeGalName string = toLower('acg_${workloadName}_${localenv}_${location}_${sequenceNumber}')   //Compute gallery names limited to alphanumeric, underscores and periods

@description('The RG where the Computer Gallery is stored')
param computeGalRG string = toLower('rg-${workloadName}-${localenv}-${location}-${sequenceNumber}')

//Name of the Image to create
@description('Name of the Image what will be created and added to the gallery e.g. desktop name like Core or Developer')
param imageName string = 'core'

//Image Template Resource Name
@description('The Name of the compute gallery image template')
param ibTemplateName string = toLower('vmi_${workloadNameShort}_${imageName}') 

//Name of the resource group that the imagebuilder will use - will be created by IB
@description('Name of the resource group that the imagebuilders packer service will use during the build - needs to be fully qualified')
param ibRGName string = toLower('/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${ibTemplateName}-packer-${utcNow()}')

//Image Configuration parameters
@description('The maximum time allowed to build the image (in minutes)')
param ibTimeout int = 180

//The VM type used to build the image.  Traditionally it is a Standard_D2s_v3 (2cpu, 8GB ram) however, if you are building a large image, you may want to use a 
//larger VM type.  Other good VMs to use are: Standard_D4ds_v4 (4cpu, 16GB ram)
@description('The VM used to actually build the image.  Note: This is not the VM that you deploy the image to.  Default: Standard_D2s_v3')
param ibVMSize string = 'Standard_D2s_v3'

@description('Regions where the image is replicated once built.  Recommended having at least one additional region')
param ibRegionReplication array = [
  location
  'westeurope'
]

@description('The name of the user assigned identity to use for the image builder')
param ibUMIName string = 'umi-imagebuilder-prod-uksouth-${sequenceNumber}'

@description('The resource group that hosts the UMI required for the image builder')
param ibUMIRG string = toLower('rg-${workloadName}-${localenv}-${location}-${sequenceNumber}')

//to get the details use the powershell:
//Note, best to try and use AVD images with Gen2.  AVD images provide multisession and Gen2 provides best performance.
// $locName = 'uksouth'
// Get-AzVMImagePublisher -Location $locName | Select PublisherName   #Typically MicrosoftWindowsDesktop
// Get-AzVMImageOffer -Location $locName -PublisherName 'MicrosoftWindowsDesktop' | Select Offer  #Typically Windows-10, Windows-11, office-365

// Get-AzVMImageSku -Location $locName -PublisherName 'MicrosoftWindowsDesktop' -Offer 'Windows-10' | Select Skus  #Example win10-22h2-avd-g2
// #OR
// Get-AzVMImageSku -Location $locName -PublisherName 'MicrosoftWindowsDesktop' -Offer 'office-365' | Select Skus  #Example win10-22h2-avd-m365 (includes office 365 apps)

//You can, of course, also use your own custom images by pointing to a gallery image.

@description('The source image used for the image being created')
param ibSourceImage object = {
  offer: 'office-365'
  publisher: 'MicrosoftWindowsDesktop'
  sku: 'win11-22h2-avd-m365'
  type: 'PlatformImage'
  version: 'latest'
}

@description('Set the disk size to the same size as the base image.')
param ibDiskSizeOverride int = 127

@description('The Name of the Zip file uploaded by the calling build script that contains the scripts to be used by the Image Builder')
param ibBuildScriptZipName string = 'buildscripts.zip'

@description('The SAS token that will be passed to the Image Builder build script to allow it to access the Build Scripts')
param ibBuildScriptSasProperties object = {
  signedPermission: 'rl'
  signedResource: 'c'
  signedProtocol: 'https'
  signedExpiry: dateTimeAdd(utcNow('u'), 'PT${ibTimeout}M')
  canonicalizedResource: '/blob/${storageRepoName}/${containerIBScripts}'
}

@description('The SAS token that will be passed to the Image Builder build script to allow it to access the Software repository')
param ibBuildSoftwareSasProperties object = {
  signedPermission: 'rl'
  signedResource: 'c'
  signedProtocol: 'https'
  signedExpiry: dateTimeAdd(utcNow('u'), 'PT${ibTimeout}M')
  canonicalizedResource: '/blob/${storageRepoName}/${containerIBSoftware}'
}

@description('The location on the Image Builder VM where the build scripts are uploaded an unpacked to.  Note backslash must be escaped')
param localBuildScriptFolder string = 'C:\\BuildScripts'

//VARIABLES
var buildScriptsSourceURI = '${storageRepo.properties.primaryEndpoints.blob}${containerIBScripts}/${ibBuildScriptZipName}'
var storageAccountSASTokenScriptBlob = listServiceSas(storageRepo.id, '2021-04-01',ibBuildScriptSasProperties).serviceSasToken
var storageAccountSASTokenSWBlob = listServiceSas(storageRepo.id, '2021-04-01',ibBuildSoftwareSasProperties).serviceSasToken

//var storageAccountSASTokenFile = listServiceSas(storageRepo.id, '2021-04-01',softwareSasProperties).serviceSasToken

//RESOURCES
//Pull in the Image Gallery RG
resource CGImageRG 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: computeGalRG
}


//Pull in the image gallery
resource CGImage 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: computeGalName
  scope: CGImageRG
}

//Pull in the storage repo
resource storageRepo 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageRepoName
  scope: resourceGroup(storageRepoRG)
}

//Create a Gallery Definition
module imageDefinition '../../ResourceModules/0.9.0/modules/Microsoft.Compute/galleries/images/deploy.bicep' = {
  name: 'imageDefinition'
  scope: CGImageRG
  params: {
    galleryName: CGImage.name
    location: location
    tags: tags
    name: imageName
    osState: 'Generalized'
    osType: 'Windows'
    description: 'Image Definition for ${imageName}'
    hyperVGeneration: 'V2'
    minRecommendedMemory: 4
    minRecommendedvCPUs: 2
    offer: ibSourceImage.offer
    publisher: publisher
    sku: imageName
  }

}

//Create the Image template
module imageTemplate '../../ResourceModules/0.9.0/modules/Microsoft.VirtualMachineImages/imageTemplates/deploy.bicep' = {
  name: 'imageTemplate'
  scope: CGImageRG

  params: {
    location: location
    tags: tags
    name: ibTemplateName
    imageSource: ibSourceImage
    userMsiName: ibUMIName
    userMsiResourceGroup: ibUMIRG
    stagingResourceGroup: ibRGName

    //Build config
    buildTimeoutInMinutes: ibTimeout
    osDiskSizeGB: ibDiskSizeOverride
    vmSize: ibVMSize

    //Customisation - can be any of File (for copy), Powershell (windows), Shell (linux), WindowsRestart or WindowsUpdate
    //Note, all scripts need to be publically acessible.  Alternativly you need to copy the scripts/artifacts from a private location
    //to the VM itself in order to run them.  This is done using the File customisation step.  the way to look at this is that
    //the buildVM, which is not on your network, needs to be able to see them.
    
    customizationSteps: [
      //Copy the buildscripts.zip from storage blob to the VM using powershell and decompress it installing the AZ modules at the same time
      //replace storagedomain with endpoint blob from the storage account outputs??
      {
        type: 'PowerShell'
        name: 'DownloadExpandBuildScripts'
        runElevated: true
        inline: [
          '$storageAccount = "${storageRepoName}"'
          //'Invoke-WebRequest -Uri "${storageRepo.properties.primaryEndpoints.blob}${buildScriptContainer}/${buildScriptZipName}" -OutFile "${buildScriptZipName}"'
          'Invoke-WebRequest -Uri "${storageRepo.properties.primaryEndpoints.blob}${containerIBScripts}/${imageName}/${ibBuildScriptZipName}?${storageAccountSASTokenScriptBlob}" -OutFile "${ibBuildScriptZipName}"'
          'New-Item -Path "C:\\BuildScripts" -ItemType Directory -Force'
          'Expand-Archive -Path "${ibBuildScriptZipName}" -DestinationPath "${localBuildScriptFolder}" -Force'
        ]
      }

      //Run the software installer script
      {
        type: 'PowerShell'
        name: 'DownloadAndRunInstallerScript'
        runElevated: true
        inline: [
          'Set-ExecutionPolicy Bypass -Scope Process -Force'
          'C:\\BuildScripts\\InstallSoftware.ps1 "${storageRepoName}" "${storageAccountSASTokenSWBlob}" "${containerIBSoftware}" "${localBuildScriptFolder}"'
        ]
      }

      //Run a validation script to ensure the build was successful
      {
        type: 'PowerShell'
        name: 'RunValidationScript'
        runElevated: true
        inline: [
          'C:\\BuildScripts\\ValidateEnvironment.ps1'
        ]
      }

      //Remove the build scripts directory
      {
        type: 'PowerShell'
        name: 'RemoveBuildScriptsDirectory'
        runElevated: true
        inline: [
          'Remove-Item -Path C:\\BuildScripts -Recurse -Force'
        ]
      }

      //Restart the VM
      {
        type: 'WindowsRestart'
        restartTimeout: '30m'
      }

      //Run windows updates
      {
        type: 'WindowsUpdate'
        searchCriteria: 'IsInstalled=0'
        filters: [
          'exclude:$_.Title -like "*Preview*"'
          'include:$true'
        ]
        updateLimit: 500
      }

      //One final restart of the VM
      {
        type: 'WindowsRestart'
        restartTimeout: '30m'
      }
    ]

    //Distribution
    sigImageDefinitionId: imageDefinition.outputs.resourceId
    managedImageName: ibTemplateName
    unManagedImageName: ibTemplateName
    imageReplicationRegions: ibRegionReplication
      
  }
}

output imageTemplateName string = imageTemplate.outputs.name
output storageURI string = buildScriptsSourceURI
