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

// @description('Required: An object (think hash) that contains the tags to apply to all resources.')
// param tags object

// @description('Required: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
// param diagnosticWorkspaceId string

// @description('Optional: Log retention policy - number of days to keep the logs.')
// param diagnosticRetentionInDays int = 30

// //Identity
// @description('Required: The name of the domain to join the VMs to')
// param domainName string

// @description('Optional: the maximum number of users allowed on each host (Host Session Limit)')
// param maxUsersPerHost int = 4

// @description('Optional: The type of load balancer to use for hosts - either breadth or depth')
// @allowed([
//   'BreadthFirst'
//   'DepthFirst'
// ])
// param loadBalancerType string = 'BreadthFirst'

@description('Optional. Host Pool token validity length. Usage: \'PT8H\' - valid for 8 hours; \'P5D\' - valid for 5 days; \'P1Y\' - valid for 1 year. When not provided, the token will be valid for 48 hours.')
param tokenValidityLength string = 'PT8H'

//This parameter is a special case as it is a parameter that should NOT be passed in from other scripts or modules.  Why?  Certain commands are only
//available to parameters such as utcNow, so this is where it is defined.  In this case we care getting the UTC time right now.
//REf: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-date#utcnow
@description('Generated. Do not provide a value! This date value is used to generate a registration token.')
param baseTime string = utcNow('u')

// @description('Required: The ID of the USER to add to the Application Group as a Desktop Virtualization User')
// param appGroupUserID string

//The content of this ID, while a parameter is actually static and comes from the Powershell command:
//(Get-AzRoleDefinition -Name "Desktop Virtualization User").id
// @description('Optional: The static ID of the RBAC group to add the user to.  This defaults to Desktop Virtualization User')
// param appGroupRoleDefinitionID string = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'

//VARIABLES
var hostPoolName = toLower('hvdpool-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolWorkspaceName = toLower('vdws-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolAppGroupName = toLower('vdag-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolScalePlanName = toLower('vdscaling-${workloadName}-${location}-${localEnv}-${uniqueName}')

//This variable does a Date/Time addition calculation using the baseTime above and adding the token time to it
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-date#datetimeadd
var tokenExpirationTime = dateTimeAdd(baseTime, tokenValidityLength)

//Create the Host Pool
//Note: This also sets some example maintenance windows.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.desktopvirtualization/hostpools?tabs=bicep&pivots=deployment-language-bicep
// resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' = {
//   name: hostPoolName
//   location: location
//   tags: tags
//   properties: {
//     //You will need registrationInfo, preferredAppGroupType, loadBalancerType, the VMTemplate
//     //Suggestion to use:
//     // galleryImageOffer: 'office-365'
//     // galleryImagePublisher: 'microsoftwindowsdesktop'
//     // galleryImageSKU: 'win11-22h2-avd-m365'
//   }
// }

// resource hostPool_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${hostPoolName}-diag'
//   //Fill out the host pool diagnostics
// }

//Create the Application Group and connect it to the host pool
//Application Groups are the third layer in AVD. they are a container for AVD "applications" which include Desktops or Application (RemoteApp)
//In this case we are wanting a full desktop rather than just apps which run on a hidden desktop
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.desktopvirtualization/applicationgroups?pivots=deployment-language-bicep
// resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = {
//   name: hostPoolAppGroupName
//   location: location
//   tags: tags
//   properties: {
//     //Up to you
//   }
// }

//Add the user that is building this deployment to the application group
//First: Get the Role Definition of the "Desktop Virtualization User" role type
//Note the scope here - this specifically calls out to the subscription for the details
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac
// resource DVURoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: appGroupRoleDefinitionID
// }

//Then add the user to that role on the App Group
//Note that the Name field here used guid().  This creates the required globally unique GUID for this particular role assignment
//But it also needs to be deterministic (i.e. repeatable) otherwise it will create a new user every time this runs.
//It will grant the "Desktop Virtualization User" RBAC control by default.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.authorization/roleassignments?tabs=bicep&pivots=deployment-language-bicep
// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   //Up to you
// }

//Configure the diagnostics for the application group
// resource appGroup_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${hostPoolAppGroupName}-diag'
//   //More diagnostics
// }

//Create the Workspace and connect it to the application group
//A workspace is a grouping of "Application Groups" and is the second layer in AVD.  It provides the "workspace" you see when you connect to the
//web portal or use the Remote Desktop client.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.desktopvirtualization/workspaces?tabs=bicep&pivots=deployment-language-bicep
// resource workspace 'Microsoft.DesktopVirtualization/workspaces@2022-09-09' = {
//   name: hostPoolWorkspaceName
//   location: location
//   tags: tags
//   properties: {
//     //up to you
//   }
// }

//Configure the diagnostics for the workspace
// resource workspace_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${hostPoolWorkspaceName}-diag'
//   //Up to you
// }

//The bit below is OPTIONAL
//Deploy the scaling plan and link it to the host pool - note this does not have any schedules set at this time
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.desktopvirtualization/scalingplans?tabs=bicep&pivots=deployment-language-bicep
// resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2022-09-09' = {
//   name: hostPoolScalePlanName
//   location: location
//   tags: tags
//   //Up to you
// }

// resource scalingPlan_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${hostPoolScalePlanName}-diag'
//   //Up to you
// }


output hostPoolName string = hostPoolName
output hostPoolWorkspaceName string = hostPoolWorkspaceName
output hostPoolAppGroupName string = hostPoolAppGroupName
output hostPoolScalePlanName string = hostPoolScalePlanName
output tokenExpirationTime string = tokenExpirationTime
// output hostPoolId string = hostPool.id
// output appGroupId string = appGroup.id
// output workspaceId string = workspace.id
// output scalingPlanId string = scalingPlan.id
