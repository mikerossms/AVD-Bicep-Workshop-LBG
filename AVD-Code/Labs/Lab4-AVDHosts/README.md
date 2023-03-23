# Lab 3 - AVD Hosts

This is the final lab in the series.  It builds on everything we have so far deployed and adds the compute nodes (hosts) to the host pool.

## Deploying the Lab

As with Lab 3, this is the recommended deloyment script.  Ad additional (optional) parameter has been added that will deploy a number og hosts for you to test.  Please keep this figure between 1 and 3.

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -updateVault $false -numberOfHostsToDeploy 1
```

## What will happen

This will take a while but it will create a new virtual machine with its own disk and network interface.  It will then repeat this up to the figure you set in "numberOfHostsToDeploy".  Each host is then added to the domain AND the host pool and some additional components are added such as monitoring and AntiMalware.

## Why do this?

Well you do need something to log into don't you...

## Getting to your shiny new desktop

You will need to complete the following final steps before trying to log into your new desktop make sure that:

1. Your host has provisioned correctly as is running
1. Your host appears in your host pool as Running
1. You have added the user you will be logging in with to "Assignments" in the Application Group

Then open a browser and connect to https://client.wvd.microsoft.com/arm/webclient/index.html

