param nsgName string = 'nsgRGModule'
param location string = 'uksouth'

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' ={
  name: nsgName
  location: location
}
