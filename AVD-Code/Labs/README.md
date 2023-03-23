# AVD Template Code / Labs Deployment

The code in this folder is to provide a skelington version of the AVD deployment code for you to work on.  In every case the resource / module call has been provided and it will be up to you to determine the right properties, parameters and variables to fill in.

This is broken down into five folders:

1. Lab1-Diag - Setting up diagnostics
2. Lab2-BaseInfra - Setting up the vnets and vault
3. Lab3-AVD - Setting up the workspace, app group and host pool
4. Lab4-AVDHosts - Adding hosts
5. TemplateOnly - If you fancy a greater challenge, this is the bare minimum template code to build all 4 labs on.

In each of the "Labs", you are given a template code base to start from.  Labs are itterative, so you you run Lab4, a fully working code base from Lab3 will be included.  so even if you dont manage to complete a Lab, you can move onto the next Lab if required.

Variables and Parameters have been provided in each of the bicep scripts, many with defaults already set.  You need to uncomment the ones you need and determine if any set value is correct

As this is a BICEP not a Powershell workshop, the powershell script "deploy.ps1" has been provided.  Each lab adds to the code base for that particular Labs requirements.  It contains everything needed to run the bicep core successfully including logging you into azure and managing the naming of your resources.  A lot of it is commented out and you will need to uncomment as you progress through the templates.

It deploys all the required components including networking, diagnostics, keyvault and AVD.  Each script is documented so you can see what each part of it does and how it interacts with other parts.  All resources and any relevant code is also referenced to the documentation within Microsoft Learn.

I would always recommend reading and understanding the references provided with each resource and try and work out what the content should be, but if you get really stuck you can refer to the "FullCode" version which provides a complete and working example.  If you do, please take the time to understand the code and feel free to ask questions.

The folder structure consists of:

| Folder | File | Description |
| --- | --- | --- |
| Bicep/Diagnostics | diagnostics.bicep | This will deploy a Log Analytics service used to provide diagnostic logs for all the other services |
| Bicep/Infrastructure | backplane.bicep | This deploys all the base-line infrastructure required |
| Bicep/Infrastructure | network.bicep | This deploys the networking infrastructutre |
| Bicep/Infrastructure | keyvault.bicep | This deploys the keyvault infrastructure |
| Bicep/Infrastructure | hostpool.bicep | This deploys the hostpool, app group and workspace infrastructure |
| Bicep/Infrastructure | moduleRemotePeer.bicep | This is used my the network module to create peering to the AADDS |
| Bicep/Hosts | deployHosts.bicep | This deploys a number of hosts calling the moduleHosts each time |
| Bicep/Hosts | moduleHosts.bicep | This does the actual deployment of the host, joins it to the domain, adds antimalware and monitoring then adds it to the host pool |
| Script | deploy.ps1 | This is the script that actually does the deployment of the bicep resources |

## The deployment script

Deploying bicep code can, of course, just be done through either powershell or the CLI, however there are a number of step required to deploy an AVD solution outwith the deploying of just bicep.  These include connecting to Azure, gathering the domain and local passwords, getting the ID of the deploying user, managing the registration tokens and (more advanced) using the REST API to change the name of the desktop.

You will be assigned a unique identifier and dedicated VNET address range (CIDR) that you MUST use throughout the course.  This ensures that your resources do not clash with anyone elses as we will all be working in a single shared subscription.

As you work through the course, you will uncomment more and more of the script.  You only need to provide vmjoiner and local admin passwords when you are ready to deploy the keyvault.  On successful deployment of the keyvault you are not likley to need to provide them again.

### Lab 1

```Powershell
cd Scripts
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor"
```

### Lab 2

**Initial Run**

```Powershell
cd Scripts
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -updateVault $false
```

At this point you will have a "context" in VSCode that will allow you to continue running code without the need to log in again so you can add the "-dologin $false"

**Up to but NOT including keyvault**

So during the first stages (up to but not including keyvault) use this:

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -dologin $false -updateVault $false
```

**Deploying the Keyvault**

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -dologin $false -updateVault $true
```

**After deploying the Keyvault**

The script itself should be well enough commented for it to make sense however for each deployment there are a few parameters that need to be set:

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -dologin $false -updateVault $false
```

### Lab 3/4

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -dologin $false -updateVault $false
```

If you do forget any of the parameters, dont worry.  The parameters are there to stop you being pestered unnecessarily by the script so if you forget one you may just need to answer some additional questions

NOTE:  You are, of course, more than welcome to hard code the unique identifier and CIDR into the powershell script and remove the "mandatory" tag.

## Getting to your shiny new desktop

You will need to complete the following final steps before trying to log into your new desktop make sure that:

1. Your host has provisioned correctly as is running
1. Your host appears in your host pool as Running
1. You have added the user you will be logging in with to "Assignments" in the Application Group

Then open a browser and connect to https://client.wvd.microsoft.com/arm/webclient/index.html
