// Deploys the common infrastrcture required to support the Hub
// built as RG scope

//Build out:
//vnet + azure firewall subnet
//azure firewall
//peering to Entra DS
//DNS on vnet to use Entra DS DNS

targetScope = 'resourceGroup'

//Parameters
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@description('Workload Name')
param workloadName string = 'LBGCentralHub'

@description('Sequence Number')
param sequenceNum string = '001'

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  WorkloadName: workloadName
  BusinessCriticality: 'medium'
  CostCentre: 'csu'
  Owner: 'Quberatron'
  DataClassification: 'general'
}

var fwpIPName = 'pip-${workloadName}-fw-${localenv}-${location}-${sequenceNum}'
var fwmpIPName = 'pip-${workloadName}-fwman-${localenv}-${location}-${sequenceNum}'
var vnetName = 'vnet-${workloadName}-${localenv}-${location}-${sequenceNum}'
var fwPolName = 'fwpol-${workloadName}-${localenv}-${location}-${sequenceNum}'
var fwName = 'firewall-${workloadName}-${localenv}-${location}-${sequenceNum}'



//Create the public ip address for the firewall
module FWpublicIpAddress '../ImageBuilder/ResourceModules/0.11.0/modules/network/public-ip-address/main.bicep' = {
  name: 'FWpublicIpAddress'
  params: {
    name: fwpIPName
    location: location
    tags: tags
    publicIPAllocationMethod: 'Static'
  }
}

//Create the public ip address for the firewall management
module FWMpublicIpAddress '../ImageBuilder/ResourceModules/0.11.0/modules/network/public-ip-address/main.bicep' = {
  name: 'FWMpublicIpAddress'
  params: {
    name: fwmpIPName
    location: location
    tags: tags
    publicIPAllocationMethod: 'Static'
  }
}

//Get the Entra DS Vnet (PROD Sub)
resource vnetEntraDS 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'aadds-vnet'
  scope: resourceGroup('ea66f27b-e8f6-4082-8dad-006a4e82fcf2','RG-EntraDomainServices')
}

//Create the central hub vnet
module vnet '../ImageBuilder/ResourceModules/0.11.0/modules/network/virtual-network/main.bicep' = {
  name: 'vnet'
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: [
      '10.200.150.0/24'
    ]
    dnsServers: [
      '10.99.99.4'
      '10.99.99.5'
    ]
    subnets: [
      {
        addressPrefix: '10.200.150.0/26'
        name: 'AzureFirewallSubnet'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        addressPrefix: '10.200.150.64/26'
        name: 'AzureFirewallManagementSubnet'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
    peerings: [
      {
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: false
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'EntraDS-${workloadName}'
        remoteVirtualNetworkId: vnetEntraDS.id
        useRemoteGateways: false
      }
    ]
  }
}

//Create the firewall policy - module preferred but does not support basic tier
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2022-01-01'= {
  name: fwPolName
  location: location
  tags: tags
  properties: {
    threatIntelMode: 'Alert'
    sku: {
      tier: 'Basic'
    }
  }
}

//Create the basic firewall
module firewall '../ImageBuilder/ResourceModules/0.11.0/modules/network/azure-firewall/main.bicep' = {
  name: 'firewall'
  params: {
    name: fwName
    location: location
    tags: tags
    azureSkuTier: 'Basic'
    managementIPResourceID: FWMpublicIpAddress.outputs.resourceId
    publicIPResourceID: FWpublicIpAddress.outputs.resourceId
    vNetId: vnet.outputs.resourceId
    //firewallPolicyId: firewallPolicy.outputs.resourceId
    firewallPolicyId: firewallPolicy.id
  }
}

//Assign DNS
