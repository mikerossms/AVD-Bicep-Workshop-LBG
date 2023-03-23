/*
This BICEP script sets up a Kevault to contain the domain admin password and host local admin password.
*/

//PARAMETERS
@description ('Required: The Azure region to deploy to')
param location string

@description('Required: The name of the keyvault to be created.')
param keyVaultName string

@description('Required: An object (think hash) that contains the tags to apply to all resources.')
param tags object

@description('Required: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string

@description('Optional: Log retention policy - number of days to keep the logs.')
param diagnosticRetentionInDays int = 30

@secure()
@description('Required: The domain admin password to be stored in the keyvault')
param domainAdminPassword string

@secure()
@description('Required: The local admin password to be stored in the keyvault')
param localAdminPassword string


//VARIABLES

//RESOURCES
//Deploy a keyvault
//Note: By default a keyvault cannot be deleted (purged), so the parameters below specifically override that behaviour
//Note: We are also allowing AzureServices to access the vault but otherwise deny access.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.keyvault/vaults?tabs=bicep&pivots=deployment-language-bicep 
resource Vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    //enablePurgeProtection: false (only if soft delete is set to true)
    enableRbacAuthorization: true
    enableSoftDelete: false
    tenantId: tenant().tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource virtualNetwork_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticWorkspaceId)) {
  name: '${keyVaultName}-diag'
  scope: Vault
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//Add the Domain Admin Password securet to the vault
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.keyvault/vaults/secrets?pivots=deployment-language-bicep
resource DomainAdminPwd 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = if (!empty(domainAdminPassword)) {
  name: 'DomainAdminPassword'
  parent: Vault
  properties: {
    value: domainAdminPassword
    contentType: 'password'
  }
}

//Add the Local Admin Password securet to the vault
resource LocalAdminPwd 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = if (!empty(localAdminPassword)) {
  name: 'LocalAdminPassword'
  parent: Vault
  properties: {
    value: localAdminPassword
    contentType: 'password'
  }
}

//OUTPUTS
output keyVaultName string = Vault.name
output keyVaultId string = Vault.id
output keyVaultUri string = Vault.properties.vaultUri
