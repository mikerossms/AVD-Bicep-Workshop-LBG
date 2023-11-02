//So take a look at this code and see if you can spot what is wrong and why

resource localNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: 'vnet-avd-local'
}

resource remoteNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: 'vnet-identity'
  scope: resourceGroup('rg-identity')
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
resource virtualNetworkPeeringFromRemote 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'local-from-remote'
  parent: remoteNetwork
  properties: {
    remoteVirtualNetwork: {
      id: localNetwork.id
    }
  }
}
