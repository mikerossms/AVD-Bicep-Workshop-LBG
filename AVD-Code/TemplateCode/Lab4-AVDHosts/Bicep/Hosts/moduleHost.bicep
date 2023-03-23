/*
This module is used to build a host vm and add them to both the host pool and the AD server.  Once these are up and running you should
be able to log into AVD.
*/

// @description ('Required: The Azure region to deploy to')
// param location string

// @description ('Required: The local environment - this is appended to the name of a resource')
// @allowed([
//   'dev'
//   'test'
//   'uat'
//   'prod'
// ])
// param localEnv string

// @description ('Required: A unique name to define your resource e.g. you name.  Must not have spaces')
// @maxLength(6)
// param uniqueName string

// @description ('Required: The name of the workload to deploy - will make up part of the name of a resource')
// param workloadName string

// @description('Required: An object (think hash) that contains the tags to apply to all resources.')
// param tags object

// //Host Settings
// @description('Required: The local admin user name for the host')
// param adminUserName string

// @description('Required: The local admin password for the host (secure string)')
// @secure()
// param adminPassword string

// @description('Required: The Domain account username that will be used to join the host to the domain')
// param domainUsername string

// @description('Required: The Domain account password that will be used to join the host to the domain (secure string)')
// @secure()
// param domainPassword string

// @description('Required: The name of the domain to join the VMs to')
// param domainName string

// @description('Required: The OU path to join the VMs to (i.e. the LDAP path within the AD server visible under "users and computers")')
// param domainOUPath string

// @description('Optional: The size of the VM to deploy.  Default is Standard_D2s_v3')
// param vmSize string = 'Standard_D2s_v3'

// @description('Required: The ID of the subnet to deploy the VMs to')
// param subnetID string

// //HostPool settings
// @description('Required: The name of the host pool to add the hosts to')
// param hostPoolName string

// param hostNumber int = 1
// param hostPoolToken string

// //VARIABLES
// //the base base name for each VM created
// var vmName = toLower('host-${workloadName}-${location}-${localEnv}-${uniqueName}-${hostNumber}')

// //the base host name (i.e. within windows itself) for each VM created
// var vmHostName = toLower('host${workloadName}${uniqueName}${hostNumber}')

// //the base Network Interface name for each VM created
// var vmNicName = toLower('nic-${workloadName}-${location}-${localEnv}-${uniqueName}-${hostNumber}')

//The version of windows to deploy
//This is set to the Multisession version of Windows 11 and includes office 365
//Ref: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage
// var vmImageObject = {
//   offer: 'To fill in'
//   publisher: 'To fill in'
//   sku: 'To fill in' // Suggest windows 11 multisession with Office 365
//   version: 'To fill in'
// }

//A publically available zip file that contains a microsoft curated script to handle the join of a host to the host pool
//Note we are using an environment variable here to manage the domain element.  this is good practice.
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-deployment#environment 
// var dscConfigURL = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration.zip'


//RESOURCES
//Create Network interfaces for each of the VMs being deployed
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/networkinterfaces?tabs=bicep&pivots=deployment-language-bicep 
// resource vmNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
//   name: vmNicName
//   location: location
//   tags: tags
//   properties: {
//     //You will need ipConfigurations which reference the subnetID
//   }
// }

//Deploy The virtual machine itself
//ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.compute/virtualmachines?tabs=bicep&pivots=deployment-language-bicep 
// resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
//   name: vmName
//   location: location
//   tags: tags
//   identity: {
//     type: 'SystemAssigned'
//   }
//   properties: {
//     //The size of the VM to deploy
//     hardwareProfile: {
//       vmSize: vmSize
//     }

//     storageProfile: {
//       //You will neeed the image reference to use and the OS disk type
//     }

//     osProfile: {
//       //Set up the host VM windows defaults e.g. local admin, name, patching etc.
//       //You will need to provide LOCAL admin creds and some Windows config
//       }
//     }

//     //The network interface to connect the VM to
//     networkProfile: {
//       //You will need to link to the nic you created
//     }

//     //Enable the boot diagnostics
//     diagnosticsProfile: {
//       bootDiagnostics: {
//         enabled: true
//       }
//     }
//   }
// }

//VM Extensions - these are used to carry out actions and install components onto the VM
//Bicep naturally tries and deploy these in parallel which, depending on what the extension is doing can cause conflicts
//As a general rule of thumb it is usually a good idea to deploy extensions in a serial fashion using "dependsOn" to ensure they are deployed in the correct order
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.compute/virtualmachines/extensions?tabs=bicep&pivots=deployment-language-bicep

//KEY NOTE: Extensions need to deploy sequentially.  Bicep will try and deploy them in parallel.  What do you need to add to force the correct order?

//Anti Malware Extension
// resource VMAntiMalware 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
//   name: 'AntiMalware'
//   parent: vm
//   location: location
//   tags: tags
//   properties: {
//     //Work out the properties for extension
//   }
// }

//Monitoring Extension which adds the monitoring agent to the VM
// resource VMMonitoring 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
//   name: 'AzureMonitorWindowsAgent'
//   parent: vm
//   location: location
//   tags: tags
//   properties: {
//     //Work out the properties for extension
//   }
// }


//Join the Domain (you can also now join the AAD in certain scenarios, but AVD is not yet supported for anything other than personal machines)
//Domain join restarts the VM, so it is a good idea to make sure nothing else is being deployed at the same time (using dependsOn)
//This is provided and can be used as is
// resource VMDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
//   name: 'JoinDomain'
//   parent: vm
//   location: location
//   tags: tags
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'JsonADDomainExtension'
//     typeHandlerVersion: '1.3'
//     autoUpgradeMinorVersion: true
//     settings: {
//       name: domainName
//       OUPath: domainOUPath
//       user: domainUsername
//       restart: 'true'
//       options: '3'
//     }
//     protectedSettings: {
//       password: domainPassword
//     }
//   }
// }

//Finally join the VM to the AVD Host Pool using a Desired State Configuration extension deployment
//Generally it is a good idea to connect the VM to the host pool AFTER adding to AAD.  Not critical though
//Ref: https://learn.microsoft.com/en-us/azure/active-directory-domain-services/join-windows-vm-template
//Note: the reference is for an ARM template but the same parameters apply.

// resource JoinAVDHostPool 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
//   name: 'JoinAVDHostPool'
//   parent: vm
//   location: location
//   tags: tags
//   properties: {
//     publisher: 'Microsoft.Powershell'
//     type: 'DSC'
//     typeHandlerVersion: '2.73'
//     autoUpgradeMinorVersion: true
//     settings: {
//       modulesUrl: dscConfigURL
//       configurationFunction: 'Configuration.ps1\\AddSessionHost'
//       properties: {
//         //Fill in the missing properties
//       }
//     }
//   }
// }
