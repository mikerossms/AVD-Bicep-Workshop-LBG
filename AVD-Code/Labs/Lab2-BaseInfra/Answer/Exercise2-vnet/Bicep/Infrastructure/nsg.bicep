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

@description('Optional: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string = ''

//VARIABLES
var nsgName = toLower('nsg-${workloadName}-${location}-${localEnv}-${uniqueName}')
var nsgAVDRuleName = toLower('AllowRDPInbound')
var nsgAVDRuleNameSSH = toLower('AllSSHInbound')

//Create the Network Security Group (there is very little to creating one, but it is a good idea to have one for each subnet)
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/networksecuritygroups?tabs=bicep&pivots=deployment-language-bicep
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  tags: tags
}

//Enable Diagnostics on the NSG
//In this case we have a scope in the resource which defines which resource that this diagnostic setting is for
//We are also using some logic, so if this is not passed in from the parent, then this will be skipped without causing errors
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.insights/diagnosticsettings?tabs=bicep&pivots=deployment-language-bicep
resource networkSecurityGroup_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticWorkspaceId)) {
  name: '${nsgName}-diag'
  scope: networkSecurityGroup
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

//Set up the AVD rule for the NSG
//Note: AVD does not require RDP access from anywhere else as the connection is handled by the PaaS service underneath
//There are other forms of connection available as well, but this is the most common.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/networksecuritygroups/securityrules?tabs=bicep&pivots=deployment-language-bicep
resource securityRule 'Microsoft.Network/networkSecurityGroups/securityRules@2022-07-01' = {
  name: nsgAVDRuleName
  parent: networkSecurityGroup
  properties: {
    //Need to enable port TCP/3389 from the virtualnetwork
    access: 'Allow'
    protocol: 'Tcp'
    destinationPortRange: '3389'
    destinationAddressPrefix: vnetCIDR
    sourceAddressPrefix: 'VirtualNetwork'
    sourcePortRange: '*'
    direction: 'Inbound'
    priority: 100
  }
}

/*TASK*/
//Add another security rule to the NSG to allow SSH from the virtual network
//You will need to create a variable for the "name" component of the new rule
//Parameters would be:
//protocol would be 'Tcp'
//Destination port would be '22'
resource securityRule2 'Microsoft.Network/networkSecurityGroups/securityRules@2022-07-01' = {
  name: nsgAVDRuleNameSSH
  parent: networkSecurityGroup
  properties: {
    //Need to enable ping from the rest of the network
    access: 'Allow'
    protocol: 'Tcp'
    destinationPortRange: '22'
    destinationAddressPrefix: vnetCIDR
    sourceAddressPrefix: 'VirtualNetwork'
    sourcePortRange: '*'
    direction: 'Inbound'
    priority: 100
  }
}

//OUTPUTS
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/outputs?tabs=azure-powershell
output nsgName string = networkSecurityGroup.name
output nsgID string = networkSecurityGroup.id
