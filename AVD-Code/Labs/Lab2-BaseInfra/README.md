# Lab 2 - Base Infrastructure

Progressivly working towards having the required base infrastructure in place to support AVD including networks, subnets, network security groups and a keyvault.

## Deploying the Lab

This is a little more involved, though you can just run the script.  In this lab there are two mandatory parameters and a number that you might find useful.

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

## What will happen

The deployment script will create a new resource group "rg-avd-uksouth-dev-[your unique id]" that will be visible in the portal containing the base infrastructure resources (note that they are not yet connected to diagnostics).  Into this new resource this deployment (and your hard work) will create The Vnet and subnet, NSG and key vault.  It will populate the keyvault and create a peering link from the vnet to an (already defined) indentity solution (AADDS).  Have a look in the "Workshop Setup" folder if you want to see how this is built.

## Why do this?

This lays down the building blocks for AVD.  Hosts, for example, require a virtual network and subnet to connect to.  Security demands the NSG.  They keyvault is used a s a secure place to store the local and domain joiner passwords