targetScope = 'resourceGroup'

param nsgName string = 'nsgRGScoped'
param nsgModuleName string = 'nsgmodule'
param nsgModuleNameNewRG string = 'nsgmodulenewRG'
param location string = 'uksouth'

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' ={
  name: nsgName
  location: location
}

module nsgModule 'module.bicep' = {
  name: 'nsgModule'
  params: {
    nsgName: nsgModuleName
    location: location
  }
}

module nsgModuleNewRG 'module.bicep' = {
  name: 'nsgModuleNewRG'
  scope: resourceGroup('rg-mikestest-module')
  params: {
    nsgName: nsgModuleNameNewRG
    location: location
  }
}
