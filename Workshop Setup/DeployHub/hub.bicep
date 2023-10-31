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
var bastionIPName = 'pip-${workloadName}-${localenv}-${location}-${sequenceNum}'
var vnetName = 'vnet-${workloadName}-${localenv}-${location}-${sequenceNum}'
var fwPolName = 'fwpol-${workloadName}-${localenv}-${location}-${sequenceNum}'
var fwName = 'firewall-${workloadName}-${localenv}-${location}-${sequenceNum}'
var bastionName = 'bastion-${workloadName}-${localenv}-${location}-${sequenceNum}'
var lawName = 'law-${workloadName}-${localenv}-${location}-${sequenceNum}'
var ipGroupName = 'ipg-lbg-workshop'


//Create Log Analytics
module law '../ImageBuilder/ResourceModules/0.11.0/modules/operational-insights/workspace/main.bicep' = {
  name: 'law'
  params: {
    name: lawName
    location: location
    tags: tags
  }
}

//Create the public ip address for the firewall
module FWpublicIpAddress '../ImageBuilder/ResourceModules/0.11.0/modules/network/public-ip-address/main.bicep' = {
  name: 'FWpublicIpAddress'
  params: {
    name: fwpIPName
    location: location
    tags: tags
    publicIPAllocationMethod: 'Static'
    diagnosticSettings: [
      {
        name: 'diag-${fwpIPName}'
        workspaceResourceId: law.outputs.resourceId
      }
    ]
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
    diagnosticSettings: [
      {
        name: 'diag-${fwmpIPName}'
        workspaceResourceId: law.outputs.resourceId
      }
    ]
  }
}

//Create the public ip address for the Bastion
module BastionPublicIpAddress '../ImageBuilder/ResourceModules/0.11.0/modules/network/public-ip-address/main.bicep' = {
  name: 'BastionPublicIpAddress'
  params: {
    name: bastionIPName
    location: location
    tags: tags
    publicIPAllocationMethod: 'Static'
    diagnosticSettings: [
      {
        name: 'diag-${fwmpIPName}'
        workspaceResourceId: law.outputs.resourceId
      }
    ]
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
      {
        addressPrefix: '10.200.150.128/26'
        name: 'AzureBastionSubnet'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
    peerings: [
      {
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'EntraDS-${workloadName}'
        remoteVirtualNetworkId: vnetEntraDS.id
        useRemoteGateways: false
      }
    ]
    diagnosticSettings: [
      {
        name: 'diag-${vnetName}'
        workspaceResourceId: law.outputs.resourceId
      }
    ]
  }
}

//Add an IP Group - covers all the IP addresses used in the workshop
module ipGroup '../ImageBuilder/ResourceModules/0.11.0/modules/network/ip-group/main.bicep' = {
  name: 'ipGroup'
  params: {
    name: ipGroupName
    location: location
    tags: tags
    ipAddresses: [
      '10.140.0.0/24'
      '10.140.1.0/24'
      '10.140.2.0/24'
      '10.140.3.0/24'
      '10.140.4.0/24'
      '10.140.5.0/24'
      '10.140.6.0/24'
      '10.140.7.0/24'
      '10.140.8.0/24'
      '10.140.9.0/24'
      '10.140.10.0/24'
      '10.140.11.0/24'
      '10.140.12.0/24'
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

//Create a rule group
//include rules to route traffic from ip group to Entra DS
resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-04-01' = {
  name: 'DefaultNetworkRuleCollectionGroup'
  parent: firewallPolicy
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'LBG-Spokes'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Spokes-to-EntraDS'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: []
            sourceIpGroups: [
              ipGroup.outputs.resourceId
            ]
            destinationAddresses: [
              '10.99.99.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource ruleCollectionGroupApps 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-04-01' = {
  name: 'DefaultApplicationRuleCollectionGroup'
  parent: firewallPolicy
  properties: {
    priority: 300
    ruleCollections: [
      {
        name: 'InternetTraffic'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllWebOut'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*'
            ]
            sourceIpGroups: [
              ipGroup.outputs.resourceId
            ]
          }
        ]
        priority: 100
      }
    ]
  }
  dependsOn: [
    ruleCollectionGroup
  ]
}

//Create the basic firewall and associate policy
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
    firewallPolicyId: firewallPolicy.id
    diagnosticSettings: [
      {
        name: 'diag-${fwName}'
        workspaceResourceId: law.outputs.resourceId
      }
    ]
  }
}


//Add a Bastion (basic)
module bastionHost '../ImageBuilder/ResourceModules/0.11.0/modules/network/bastion-host/main.bicep' = {
  name: 'bastionHost'
  params: {
    name: bastionName
    location: location
    tags: tags
    vNetId: vnet.outputs.resourceId
    skuName: 'Basic'
    diagnosticSettings: [
      {
        name: 'diag-${bastionName}'
        workspaceResourceId: law.outputs.resourceId
      }
    ]
    bastionSubnetPublicIpResourceId: BastionPublicIpAddress.outputs.resourceId
  }
  
}

