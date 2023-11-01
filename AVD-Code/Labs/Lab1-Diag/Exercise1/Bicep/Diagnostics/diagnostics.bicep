/*
The Diagnostics BICEP script deploys a Log Analystic Workspace.
The LAW is used for general diagnostic input from all the other deployed resources
The entire bicep script will be run in "Resource Group" mode, so the resources will need to be deployed into an existing RG
*/

//TARGET SCOPE
targetScope = 'resourceGroup'

//RESOURCES

//Deploy the Log Analytics Workspace (notice the name is not actually log analytics workspace but Operational Insights)
//When you come to deploy an agent on the Hostpool Hosts, you will need to use the new Azure Monitoring Agent (AMA) and not the old Log Analytics (OMS) agent
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: 'uksouth'
  name: 'law-lbg-uksouth-dev-tomsmith'
  tags: {
    environment: 'dev'
    workload: 'lbg'
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

