/*
This module is used to build a host vm and add them to both the host pool and the AD server.  Once these are up and running you should
be able to log into AVD.
*/

@description ('Required: The Azure region to deploy to')
param location string

@description ('Required: The local environment - this is appended to the name of a resource')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param localEnv string

@description ('Required: A unique name to define your resource e.g. you name.  Must not have spaces')
@maxLength(6)
param uniqueName string

@description ('Required: The name of the workload to deploy - will make up part of the name of a resource')
param workloadName string

@description('Required: An object (think hash) that contains the tags to apply to all resources.')
param tags object

//Host Settings
@description('Required: The local admin user name for the host')
param adminUserName string

@description('Required: The local admin password for the host (secure string)')
@secure()
param adminPassword string

@description('Required: The Domain account username that will be used to join the host to the domain')
param domainUsername string

@description('Required: The Domain account password that will be used to join the host to the domain (secure string)')
@secure()
param domainPassword string

@description('Required: The name of the domain to join the VMs to')
param domainName string

@description('Required: The OU path to join the VMs to (i.e. the LDAP path within the AD server visible under "users and computers")')
param domainOUPath string

@description('Optional: The size of the VM to deploy.  Default is Standard_D2s_v3')
param vmSize string = 'Standard_D2s_v3'

@description('Required: The ID of the subnet to deploy the VMs to')
param subnetID string

//HostPool settings
@description('Required: The name of the host pool to add the hosts to')
param hostPoolName string

@description('Required: The number associated with this particular host')
param hostNumber int = 1

@description('The token required to register the VM with the Host Pool')
param hostPoolToken string

/*TASK*/
//Build the vmImageObject with the right components to deploy a Windows 11 multisession desktop
//You will need offer,publisher,sku
//Reference: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage 

//The version of windows to deploy
//This is set to the Multisession version of Windows 11 and includes office 365
//Ref: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage
@description('optional: The Image object that contains either a gallery image (as default) or an image reference')
param vmImageObject object = {
  offer: 'office-365'
  publisher: 'microsoftwindowsdesktop'
  sku: 'win11-22h2-avd-m365'
  version: 'latest'
}

@description('Optional: The type of storage to use.  By default this is a standard SSD, for shared machines Premium/Ephemeral is usually better')
param storageAccountType string = 'StandardSSD_LRS'
