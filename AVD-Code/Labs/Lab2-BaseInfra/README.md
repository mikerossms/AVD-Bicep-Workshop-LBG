# Lab 2 - Base Infrastructure

Progressivly working towards having the required base infrastructure in place to support AVD including networks, subnets, network security groups and a keyvault.

The lab is split up into a number of exercises, each expanding on the previous one introducing new concepts

1. Exercise 1 - Deploying a VNET
1. Exercise 2 - Peering VNETs
1. Exercise 3 - Deploying a KeyVault
1. Exercise 4 - If you have time - tracking down and fixing the code

## Deploying the Lab

This is a little more involved, though you can just run the script.  In this lab there are two mandatory parameters and a number that you might find useful.

So as with Lab1, you will use the deploy.ps1 script to deploy the code.  This time, however, you will have an extra parameter of CIDR.  This will be provided to you.  It is important you use the same CIDR going forward.

```Powershell
.\deploy.ps1 -uniqueIdentifier "your username" -avdVnetCIDR "provided CIDR"
```

## What will happen

The deployment script will deploy the infrastructure resources of the Vnet and subnet, NSG and key vault.  It will populate the keyvault and create a peering link from the vnet to an (already defined) indentity solution (Entra DS).  Have a look in the "Workshop Setup" folder if you want to see how this is built.

## Why do this?

This lays down the building blocks for AVD.  Hosts, for example, require a virtual network and subnet to connect to.  Security demands the NSG.  They keyvault is used as a secure place to store the local and domain joiner passwords