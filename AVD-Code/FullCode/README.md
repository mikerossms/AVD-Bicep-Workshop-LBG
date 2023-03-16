# AVD Full Code Deployment

The code in this folder is to provide a fully working AVD solution based on a standard off the shelf Azure Marketplace Gallery image.

It deploys all the required components including networking, diagnostics, keyvault and AVD.  Each script is documented so you can see what each part of it does and how it interacts with other parts.  All resources and any relevant code is also referenced to the documentation within Microsoft Learn.

This is the code base that we will effectivly be building out using the template files.  It can be used as a reference if/when you get stuck in your deployment.

It consists of:

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

The script itself should be well enough commented for it to make sense however for each deployment there are a few parameters that need to be set:

**First Deployment**

```Powershell
cd Scripts
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor"
```

Running this will ask you to log into azure and ask you for the passwords for the local admin password (your choice) and the vmjoiner password (provided)

**Subsequent Deployment**

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -dologin $false -updateVault $false
```

This will skip both the login (you are already logged in unless you closed VSCode) and the requirement to provide passwords (they are already recorded in KeyVault)

You ALWAYS have to provide the unique identifier and will be prompted if you forget