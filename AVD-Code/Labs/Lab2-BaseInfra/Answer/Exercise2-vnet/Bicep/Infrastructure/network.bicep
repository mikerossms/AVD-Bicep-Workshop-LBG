/*
This BICEP script sets up a VNET for the AVD to reside in.
Note also that there is no TargetScope defined.  The reason for this is not that "ResourceGroup" is actually the default setting.
*/

//PARAMETERS
//As best practice it is always a good idea to try and maintain a naming convention and style for all your modules and resources
//You will notice a lot of these parameters take the same name as their parent, but notice that many are now required, feeding from the parent.
//This way, modules can be used for other projects as well without having to durplicate and edit defaults.

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

@description('Required: The address prefix (CIDR) for the virtual network.')
param vnetCIDR string

@description('Required: The address prefix (CIDR) for the virtual networks AVD subnet.')
param snetCIDR string

@description('Optional: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string = ''

@description('Required: The ID of the of the Network Security Group to attacg to the Subnet')
param networkSecurityGroupID string

@description('Required: The IP Address of the AD Server or AADDS Server to use as the DNS server for the VNET')
param adServerIPAddresses array

//VARIABLES
var vnetName = toLower('vnet-${workloadName}-${location}-${localEnv}-${uniqueName}')
var snetName = toLower('snet-${workloadName}-${location}-${localEnv}-${uniqueName}')


//Create the virtual network (vnet) and subnet (snet) objects
//Note that the SNET will have a set of storage endpoints and keyvault endpoints enabled
//Ref: VNET: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/virtualnetworks?tabs=bicep&pivots=deployment-language-bicep
//Ref: SNET: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/virtualnetworks/subnets?pivots=deployment-language-bicep
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    //Will need to provide address space, dhcpOptions and subnets
    addressSpace: {
      addressPrefixes: [
        vnetCIDR
      ]
    }
    dhcpOptions: {
      dnsServers: adServerIPAddresses
    }
    subnets: [
      {
        name: snetName
        properties: {
            addressPrefix: snetCIDR
            networkSecurityGroup: {
              id: networkSecurityGroupID
            }
        }
      }
    ]
  }
}

/*TASK*/
//Enable diagnostic setting on the VNET
//HINT: Duplicate the resource networkSecurityGroup_diagnosticSettings and update it for the VNET
//The "name:" field should be:  name: '${vnetName}-diag'

//Diagnostics for the VNET
resource vnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticWorkspaceId)) {
  name: '${vnetName}-diag'
  scope: virtualNetwork
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}


//OUTPUTS
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/outputs?tabs=azure-powershell
output vnetName string = virtualNetwork.name
output vnetID string = virtualNetwork.id
output snetName string = virtualNetwork.properties.subnets[0].name
output snetID string = virtualNetwork.properties.subnets[0].id
