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

@description('Optional. Host Pool token validity length. Usage: \'PT8H\' - valid for 8 hours; \'P5D\' - valid for 5 days; When not provided, the token will be valid for 8 hours.')
param tokenValidityLength string = 'PT8H'

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
param appGroupRoleDefinitionID string = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'

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
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: maxUsersPerHost
    loadBalancerType: loadBalancerType
    validationEnvironment: false
    customRdpProperty: 'drivestoredirect:s:;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:0;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:0;smart sizing:i:1;dynamic resolution:i:1;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;compression:i:1'
    registrationInfo: {
      expirationTime: tokenExpirationTime
      token: null
      registrationTokenOperation: 'Update'
    }
    vmTemplate: string(vmTemplate)
    agentUpdate: {
      maintenanceWindows: [
        {
          dayOfWeek: 'Friday'
          hour: 6
        }
        {
          dayOfWeek: 'Saturday'
          hour: 8
        }
      ]
      maintenanceWindowTimeZone: 'GMT Standard Time'
      type: 'Scheduled'
      useSessionHostLocalTime: false
    }
  }
}

resource hostPool_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${hostPoolName}-diag'
  scope: hostPool
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

/*TASK*/
//Have a go at filling in the the required properties based in the reference link below
//you will need hostPoolArmPath and aplicationGroupType as the least

//Create the Application Group and connect it to the host pool
//Application Groups are the third layer in AVD. they are a container for AVD "applications" which include Desktops or Application (RemoteApp)
//In this case we are wanting a full desktop rather than just apps which run on a hidden desktop
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.desktopvirtualization/applicationgroups?pivots=deployment-language-bicep
resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = {
  name: hostPoolAppGroupName
  location: location
  tags: tags
  properties: {
    //Up to you - hostPoolArmPath, aplicationGroupType
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
  }
}

//Add the user that is building this deployment to the application group
//First: Get the Role Definition of the "Desktop Virtualization User" role type
//Note the scope here - this specifically calls out to the subscription for the details
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac
resource DVURoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: appGroupRoleDefinitionID
}

/*TASK*/
//Fill out the properties for the roleAssignment.  In this case you need to provide:
//Role definition id (the resource you have just retrieved)
//The principal ID (application group ID passed in as a parameter)
//principalType (up to you)

//Then add the user to that role on the App Group
//Note that the Name field here used guid().  This creates the required globally unique GUID for this particular role assignment
//But it also needs to be deterministic (i.e. repeatable) otherwise it will create a new user every time this runs.
//It will grant the "Desktop Virtualization User" RBAC control by default.
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.authorization/roleassignments?tabs=bicep&pivots=deployment-language-bicep
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appGroup
  name: guid(appGroup.id, appGroupUserID, appGroupRoleDefinitionID)
  properties: {
    roleDefinitionId: DVURoleDefinition.id
    principalId: appGroupUserID
    principalType: 'User'
  }
}

//diagnostic settings for the application group
resource appGroup_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${hostPoolAppGroupName}-diag'
  scope: appGroup
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


output hostPoolName string = hostPoolName
output hostPoolWorkspaceName string = hostPoolWorkspaceName
output hostPoolAppGroupName string = hostPoolAppGroupName
output hostPoolScalePlanName string = hostPoolScalePlanName
output tokenExpirationTime string = tokenExpirationTime
output hostPoolId string = hostPool.id
output appGroupId string = appGroup.id
