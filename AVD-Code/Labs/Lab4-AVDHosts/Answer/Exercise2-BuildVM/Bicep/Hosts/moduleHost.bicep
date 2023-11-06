/*
This module is used to build a host vm and add them to both the host pool and the AD server.  Once these are up and running you should
be able to log into AVD.
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

//Host Settings
@description('Required: The local admin user name for the host')
param adminUserName string

@description('Required: The local admin password for the host (secure string)')
@secure()
param adminPassword string

@description('Required: The Domain account username that will be used to join the host to the domain')
param domainUsername string

@description('Required: The Domain account password that will be used to join the host to the domain (secure string)')
@secure()
param domainPassword string

@description('Required: The name of the domain to join the VMs to')
param domainName string

@description('Required: The OU path to join the VMs to (i.e. the LDAP path within the AD server visible under "users and computers")')
param domainOUPath string

@description('Optional: The size of the VM to deploy.  Default is Standard_D2s_v3')
param vmSize string = 'Standard_D2s_v3'

@description('Required: The ID of the subnet to deploy the VMs to')
param subnetID string

//HostPool settings
@description('Required: The name of the host pool to add the hosts to')
param hostPoolName string

@description('Required: The number associated with this particular host')
param hostNumber int = 1

@description('The token required to register the VM with the Host Pool')
param hostPoolToken string

/*TASK*/
//Build the vmImageObject with the right components to deploy a Windows 11 multisession desktop
//You will need offer,publisher,sku
//Reference: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage 

//The version of windows to deploy
//This is set to the Multisession version of Windows 11 and includes office 365
//Ref: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage
@description('optional: The Image object that contains either a gallery image (as default) or an image reference')
param vmImageObject object = {
  offer: 'office-365'
  publisher: 'microsoftwindowsdesktop'
  sku: 'win11-22h2-avd-m365'
  version: 'latest'
}

@description('Optional: The type of storage to use.  By default this is a standard SSD, for shared machines Premium/Ephemeral is usually better')
param storageAccountType string = 'StandardSSD_LRS'

//VARIABLES
//the base base name for each VM created
var vmName = toLower('host-${workloadName}-${location}-${localEnv}-${uniqueName}-${hostNumber}')

//the base host name (i.e. within windows itself) for each VM created
var maxunique = take(uniqueName,5)
var vmHostName = toLower('hst${workloadName}${maxunique}${hostNumber}')

//the base Network Interface name for each VM created
var vmNicName = toLower('nic-${workloadName}-${location}-${localEnv}-${uniqueName}-${hostNumber}')

//A publically available zip file that contains a microsoft curated script to handle the join of a host to the host pool
//Note we are using an environment variable here to manage the domain element.  this is good practice.
//Ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-deployment#environment 
var dscConfigURL = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration.zip'

/*TASK*/
//Each VM being deployed is made up of a VM with storage and an operating system, a network interface and several extensions
//In this task you will need to resource and build a network interface resource called nmNic with a name of vmNicName
//It should have a location and tags as per the parameters
//Its properties should include only a privateIP address which is Dynamic and IPv4
//It should be linked to the subnetID provided as a parameter
//Reference: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/networkinterfaces?tabs=bicep&pivots=deployment-language-bicep 


//RESOURCES
//Create Network interfaces for each of the VMs being deployed
//Ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.network/networkinterfaces?tabs=bicep&pivots=deployment-language-bicep 
resource vmNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: vmNicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnetID
          }
        }
      }
    ]
  }
}

/*Task*/
//Build out the missing elements of the vm template.
//Remember that a lost of the missing informaiton is provided as parameters to this bicep script
//You will need a hardwareProfile, imageReference, to Link your network interface you created earlier
//

//Deploy The virtual machine itself
//ref: https://learn.microsoft.com/en-gb/azure/templates/microsoft.compute/virtualmachines?tabs=bicep&pivots=deployment-language-bicep 
resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    //The size of the VM to deploy
    hardwareProfile: {
      vmSize: vmSize
    }

    storageProfile: {
      //the type of the OS disk to set up and how it will be populated
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      //The OS image to deploy for this VM
      //This comes from the variable further up but could also be a custom image
      imageReference: vmImageObject
    }

    osProfile: {
      //Set up the host VM windows defaults e.g. local admin, name, patching etc.
      computerName: vmHostName
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        timeZone: 'GMT Standard Time'
        patchSettings: {
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }

    //The network interface to connect the VM to
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }

    //Enable the boot diagnostics
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
