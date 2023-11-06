//So why does this work?

resource localNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: 'vnet-avd-local'
}

resource remoteNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: 'aadds-vnet'
  scope: resourceGroup('RG-EntraDomainServices')
}

//Peering from local to remote
module virtualNetworkPeeringToRemote 'Infrastructure/moduleRemotePeer.bicep' = {
  name: 'local-to-remote'
  scope: resourceGroup()
  params: {
    connectFromVnetName: localNetwork.name
    connectToVnetID: remoteNetwork.id
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
