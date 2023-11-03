/*
This module is used to build out the host pool and its supporting components.  this is the bones of the AVD service
and provides a home for the Hosts, workspaces, application groups, and applications.
*/

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

@description('Required: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string

//AVD settings
@description('Optional: the maximum number of users allowed on each host (Host Session Limit)')
param maxUsersPerHost int = 4

@description('Optional: The type of load balancer to use for hosts - either breadth or depth')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancerType string = 'BreadthFirst'

/*TASK*/
//Using the reference here: https://en.wikipedia.org/wiki/ISO_8601#Durations
//Update the tokenValidityLength parameter below to set the default length at 8 hours

@description('Optional. Host Pool token validity length. The token will be valid for 8 hours.')
param tokenValidityLength string = <fillmein>

//This parameter is a special case as it is a parameter that should NOT be passed in from other scripts or modules.  Why?  Certain commands are only
//available to parameters such as utcNow, so this is where it is defined.  In this case we care getting the UTC time right now.
//REf: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-date#utcnow
@description('Generated. Do not provide a value! This date value is used to generate a registration token.')
param baseTime string = utcNow('u')

@description('Required: The ID of the USER to add to the Application Group as a Desktop Virtualization User')
param appGroupUserID string

/*TASK*/
//The appGRoupRoleDefinitionID needs to be configured as a globally static ID of the form 'hex-hex-hex-hex-hex'
//We need the static ID for the "Desktop Virtualization User" role.
//You can find this by running the powershell command "Get-AzRoleDefinition -Name "Desktop Virtualization User"

//ADVANCED: Could you do this programatically in Powershell and pass it in as a parameter rather than hardcoding it here

@description('Optional: The static ID of the RBAC group to add the user to.  This defaults to Desktop Virtualization User')
param appGroupRoleDefinitionID string = <fillmein>

//VARIABLES
var hostPoolName = toLower('hvdpool-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolWorkspaceName = toLower('vdws-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolAppGroupName = toLower('vdag-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolScalePlanName = toLower('vdscaling-${workloadName}-${location}-${localEnv}-${uniqueName}')

/*TASK*/
//Determining the right parameters for the template can be a bit of a challenge.  By following this:
//https://learn.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage 
//See if you can work out where the vmTemplate details have come from

//This variable does a Date/Time addition calculation using the baseTime above and adding the token time to it
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-date#datetimeadd
var tokenExpirationTime = dateTimeAdd(baseTime, tokenValidityLength)
var vmTemplate = {
    galleryImageOffer: 'office-365'
    galleryImagePublisher: 'microsoftwindowsdesktop'
    galleryImageSKU: 'win11-22h2-avd-m365'
}

/*TASK*/
//Can you fill in the missing properties for the hostpool?
//You will need registrationInfo (object), preferredAppGroupType (string), loadBalancerType (parameter), maxSessionLimit (parameter)

//ADVANCED:
//Add an agentUpdate object that will configure a maintenance window for 6pm Friday and 8pm Saturday

//Create the Host Pool
//Note: This also sets some example maintenance windows.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.desktopvirtualization/hostpools?tabs=bicep&pivots=deployment-language-bicep
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' = {
  name: hostPoolName
  location: location
  tags: tags
  properties: {
    friendlyName: 'Host Pool for ${hostPoolName}'
    description: 'Host Pool for ${hostPoolName}'
    hostPoolType: 'Pooled'
    validationEnvironment: false
    vmTemplate: string(vmTemplate)
  }
}

/*TASK*/
//Add a diagnostic settings resource for the host pool

output hostPoolName string = hostPoolName
output hostPoolWorkspaceName string = hostPoolWorkspaceName
output hostPoolAppGroupName string = hostPoolAppGroupName
output hostPoolScalePlanName string = hostPoolScalePlanName
output tokenExpirationTime string = tokenExpirationTime
output hostPoolId string = hostPool.id
