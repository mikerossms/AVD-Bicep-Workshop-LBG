// Deploys the common infrastrcture required to support the Image Builder.  

targetScope = 'subscription'

//Naming convention:
//resource-workload-environment-region-instance
//pip-sharepoint-prod-uksouth-001

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

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  WorkloadName: workloadName
  BusinessCriticality: 'medium'
  CostCentre: 'csu'
  Owner: 'AVD Squad'
  DataClassification: 'general'
}

@description('The name of the resource group to create for the common image builder components')
param rgImageName string = toLower('rg-${workloadName}-${localenv}-${location}-001')

@description('The name of the storage account to create as a software repo for the Image Builder and a place to host its common components')
param storageRepoName string = toLower('st${workloadNameShort}${localenv}${location}001')  //Storage names are alphanumeric only

@description('The name of the container to hold the scripts used to build the Image Builder')
param containerIBScripts string = 'buildscripts'

@description('The name of the container to hold the software to be installed by the Image Builder')
param containerIBSoftware string = 'software'

@description('The Name of the compute gallery')
param computeGalName string = toLower('acg_${workloadName}_${localenv}_${location}_001')   //Compute gallery names limited to alphanumeric, underscores and periods

//LAW Resource Group name
// @description ('The name of the Log Analytics Workspace Resource Group')
// param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

//LAW workspace
// @description('Log Analytics Workspace Name')
// param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

//Create the RG
resource RGImages 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgImageName
  location: location
  tags: tags
}

//Retrieve the CORE Log Analytics workspace
// resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
//   name: LAWorkspaceName
//   scope: resourceGroup(RGLAW)
// }

//Create the storage account required for the script which will build the ADDS server
module RepoStorage '../ResourceModules/0.9.0/modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'RepoStorage'
  scope: RGImages
  params: {
    location: location
    tags: tags
    name: storageRepoName
    allowBlobPublicAccess: true   //Permits access from the deploying script
    publicNetworkAccess: 'Enabled'
    // diagnosticLogsRetentionInDays: 7
    // diagnosticWorkspaceId: LAWorkspace.id
    storageAccountSku: 'Standard_LRS'
    blobServices: {
      containers: [
        {
          name: containerIBScripts
          publicAccess: 'None'
        }
        {
          name: containerIBSoftware
          publicAccess: 'None'
        }
      ]
      //diagnosticWorkspaceId: LAWorkspace.id
    }
  }
}

//Build the Compute Gallery
module galleries '../ResourceModules/0.9.0/modules/Microsoft.Compute/galleries/deploy.bicep' = {
  name: computeGalName
  scope: RGImages
  params: {
    location: location
    tags: tags
    name: computeGalName
  }
}

output imageBuilderRG string = RGImages.name
output storageRepoID string = RepoStorage.outputs.resourceId
output storageRepoName string = RepoStorage.outputs.name
output storageRepoRG string = RepoStorage.outputs.resourceGroupName
output storageRepoScriptsContainer string = containerIBScripts
output storageRepoSoftwareContainer string = containerIBSoftware
output acgName string = galleries.outputs.name
