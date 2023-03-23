/*
The Backplane is simply a way of coordinating all of the moving part of this deployment so you dont have to deploy each section individually.
This bicep script will call the following in this order:

network.bicep
keyvault.bicep
hostpool.bicep

The entire bicep script will be run in "Resource Group" mode, so the resources will need to be deployed into an existing RG

You might notice that diagnostics.bicep is not called here.  Why? Because the diagnostics bicep deploys to a different resource group to the rest of the components.

Useful links:
Resource abbreviations: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

*/

//TARGET SCOPE
targetScope = 'resourceGroup'

//PARAMETERS
//Parameters provide a way to pass in values to the bicep script.  They are defined here and then used in the modules and variables below
//Some parameters are required, some are optional.  "optional" parameters are ones that have default values already set, so if you dont
//pass in a value, the default will be used.  If a parameter does not have a default value set, then you MUST pass it into the bicep script
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters

//This is an example of an optional parameter.  If no value is passed in, UK South will be used as the default region to deploy to
@description ('Optional: The Azure region to deploy to')
param location string = 'uksouth'

//This is an example where the parameter passed in is limited to only that within the allowed list.  Anything else will cause an error
@description ('Optional: The local environment - this is appended to the name of a resource')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param localEnv string = 'dev' //dev, test, uat, prod

//This is an example of a required component.  Note there is no default value so the script will expect it to be passed in
//This is also limited to a maximum of 6 characters.  Any more an it will cause an error
@description ('Required: A unique name to define your resource e.g. you name.  Must not have spaces')
@maxLength(6)
param uniqueName string

@description ('Optional: The name of the workload to deploy - will make up part of the name of a resource')
param workloadName string = 'avd'

//This component is a bit more complex as it is an object.  This is passed in from powershell as a @{} type object
//Tags are really useful and show, as part of good practice, be applied to all resources and resource groups (where possible)
//They are used to help manage the service.  Resources that are tagged can then be used to create cost reports, or to find all resources assicated with a particular tag
@description('Optional: An object (think hash) that contains the tags to apply to all resources.')
param tags object = {
  environment: localEnv
  workload: workloadName
}

//Domain Details
//This is an example of a Required string which MUST be passed into the BICEP as a parameter from teh calling script
@description('Required: The name of the domain to join the VMs to')
param domainName string

//This is an example of a SECURE string.  this is again passed in from the calling script, but must be done so in a secure manner
//This particular parameter is passed in so that the password can be then stored in a keyvault so you dont need to keep providing it.
@secure()
@description('Required: The password for the domain admin account')
param domainAdminPassword string

//Local Host Details
@secure()
@description('Required: The password for the local admin account')
param localAdminPassword string

//VNET Details
@description('Required: The CIDR of the AVD vnet to create e.g. 10.20.30.0/24')
param avdVnetCIDR string 

@description('Required: The CIDR of the AVD Subnet to create WITHIN the vnet')
param avdSnetCIDR string

//Identity VNET Details
@description('Optional: The name of the identity vnet to peer to')
param identityVnetName string = 'vnet-identity'

@description('Optional: The resource group containing the identity vnet to peer to')
param identityVnetRG string = 'rg-identity'

@description('Required: The IP addresses of the AD server or AADDS that the VNET will used for name lookup')
param adServerIPAddresses array

@description('Required: The ID of the USER to add to the Application Group as a Desktop Virtualization User')
param appGroupUserID string

//Diagnostics
@description ('Required: The name of the resource group where the diagnostics components have been deployed to')
param rgDiagName string

@description ('Required: The name of the Log Analytics workspace in the diagnostics RG')
param lawName string

@description('Whether on not to deploy/update the keyvault')
param deployVault bool = true

//VARIABLES
// Variables are created at runtime and are usually used to build up resource names where not defined as a parameter, or to use functions and logic to define a value
// In most cases, you could just provide these as defaulted parameters, however you cannot use logic on parameters
//Variables are defined in the code and, unlike parameters, cannot be passed in and so remain fixed inside the template.
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/variables

var keyVaultName = toLower('kv-${workloadName}-${location}-${localEnv}-${uniqueName}')

//RESOURCES
//Resources are all deployed as MODULES.  Each module defines a block of BICEP code and are listed above
//Both Modules and Resources have Inputs and Outputs.
//Ref: Resources: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/resource-declaration?tabs=azure-powershell
//Ref: Modules: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules 

//Get the existing Diagnostics Module - the diagnostics module should already have been deployed to a different resource group
//Note the use of two components - existing and scope
//The existing keyword defines a resource that has already been deployed and that you are "pulling into" this deployment for use by the resources here.
//The scope defines where that resource is deployed.  In this case it is in the "resourceGoupe" in the current subscription defined by the name "rgDiagName" which is a parameter passed in
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: lawName
  scope: resourceGroup(rgDiagName)
}

//Deploy the Network resources
//Note: that we are passing in the LAWWorkspace ID from the resource we pulled in above
module Network 'network.bicep' = {
  name: 'Network'
  params: {
    location: location
    localEnv: localEnv
    uniqueName: uniqueName
    workloadName: workloadName
    tags: tags
    vnetCIDR: avdVnetCIDR
    snetCIDR: avdSnetCIDR
    diagnosticWorkspaceId: LAWorkspace.id
    identityVnetName: identityVnetName
    identityVnetRG: identityVnetRG
    adServerIPAddresses: adServerIPAddresses
  }
}

//Deploy a KeyVault - this is required to store the domain admin and local admin password
//This also stores the two admin passwords that have been passed in as parameters
//Note: This also has the keyword "if".  We really only want to deploy or update the keyvault when it is actually required.
//So on the first run of the script, or if the admin passwords change.  The reason for this is that we dont want to have
//to keep passing in the passwords every time we run the script.
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/conditional-resource-deployment
module KeyVault 'keyvault.bicep' = if (deployVault) {
  name: 'KeyVault'
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: tags
    diagnosticWorkspaceId: LAWorkspace.id
    domainAdminPassword: domainAdminPassword
    localAdminPassword: localAdminPassword
  }
}

//Deploy the HostPool resource which includes the app group and workspace as well
module HostPool 'hostpool.bicep' = {
  name: 'HostPool'
  params: {
    location: location
    localEnv: localEnv
    uniqueName: uniqueName
    workloadName: workloadName
    tags: tags
    diagnosticWorkspaceId: LAWorkspace.id
    domainName: domainName
    appGroupUserID: appGroupUserID
  }
}

//These are examples of outputs.  In this case they return to the calling script for its consumption, but in general they
//are usually used to pass outputs from bicep modules.
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/outputs?tabs=azure-powershell
output hpName string = HostPool.outputs.hostPoolName
output subNetId string = Network.outputs.snetID
output appGroupID string = HostPool.outputs.appGroupId
output appGroupName string = HostPool.outputs.hostPoolAppGroupName
output keyvaultName string = KeyVault.outputs.keyVaultName
