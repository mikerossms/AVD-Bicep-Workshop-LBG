//So why does this work?

resource localNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: 'vnet-avd-local'
}

resource remoteNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: 'aadds-vnet'
  scope: resourceGroup('RG-EntraDomainServices')
}

//Peering from Local to Remote
resource virtualNetworkPeeringToRemote 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'local-to-remote'
  parent: localNetwork
  properties: {
    remoteVirtualNetwork: {
      id: remoteNetwork.id
    }
  }
}

//Peering from remote to local
module virtualNetworkPeeringFromRemote 'Infrastructure/moduleRemotePeer.bicep' = {
  name: 'local-from-remote'
  scope: resourceGroup('RG-EntraDomainServices')
  params: {
    connectFromVnetName: remoteNetwork.name
    connectToVnetID: localNetwork.id
  }
}
