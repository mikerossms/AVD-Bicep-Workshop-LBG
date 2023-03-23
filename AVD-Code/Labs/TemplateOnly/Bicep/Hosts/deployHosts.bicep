/*
  this bicep script builds the hosts, connects them to AADDS (or ADDS) and then joins them to the host pool as well as setting up
  AntiMalware and Monitoring
*/
//TARGET SCOPE
targetScope = 'resourceGroup'

//PARAMETERS
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
param localEnv string = 'dev' 

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
@description('Required: The name of the domain to join the VMs to')
param domainName string
@description('Required: The username of the domain admin account')
param domainAdminUsername string
@description('Required: The OU path to join the VMs to (i.e. the LDAP path within the AD server visible under "users and computers")')
param domainOUPath string

//Local Host Details
@description('Required: The username for the local admin account')
param localAdminUsername string

@description('Required: The number of overall hosts to deploy.  Default is 1.')
param numberOfHostsToDeploy int = 1

@description('Required: The name of the host pool in which to deploy the hosts')
param hostPoolName string

@description('Required: The host pool token used to deploy each host into the host pool.  this token must be valid')
param hostPoolToken string

@description('Required: The ID of the subnet to connect the hosts to')
param subnetID string

@description('Required: The Name of the Keyvault to go to for the local and domain admin passwords')
param keyVaultName string

//RESOURCES
//Pull in the existing keyvault
resource KeyVault 'Microsoft.KeyVault/vaults@2022-11-01' existing = {
  name: keyVaultName
}

//Deploy the Hosts for the host pool.  this applies a FOR loop to build out <n> hosts as defined by numberOfHostsToDeploy
//Note that each host is built using a module.  This significently reduces complexity otherwise you would need to wrap a
//For loop around each of the resources being deployed.  This way you can do it just once:
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/loops 
module Hosts 'moduleHost.bicep' = [for i in range(0, numberOfHostsToDeploy): {
  name: 'AVDHost${i}'
  params: {
    location: location
    localEnv: localEnv
    uniqueName: uniqueName
    workloadName: workloadName
    tags: tags
    hostNumber: i
    adminUserName: localAdminUsername
    adminPassword: KeyVault.getSecret('LocalAdminPassword')
    domainUsername: domainAdminUsername
    domainPassword: KeyVault.getSecret('DomainAdminPassword')
    domainOUPath: domainOUPath
    domainName: domainName
    subnetID: subnetID
    hostPoolName: hostPoolName
    hostPoolToken: hostPoolToken
  }
}]
