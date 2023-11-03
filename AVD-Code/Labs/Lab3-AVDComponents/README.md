# Lab 3 - AVD Infrastructure

Now that the right base infrastructure is in place we need to add the supporting cast of AVD components to sit on top of it.

## Deploying the Lab

This lab is back to basic on the deployment but with one additional recommended parameter (saves a lot of typing).  The reason for the parameter is to prevent the vault from being updated with a new local admin and vm joiner password.

```Powershell
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor" -avdVnetCIDR "provided CIDR" -updateVault $false
```

## What will happen

The deployment script will add to the existing resource avd resource group to create the required AVD components.  These include the Host Pool, Application Group and Workspace as well as the Scaling Plan (optional)

## Why do this?

AVD is a PaaS service that mirrors something akin to Remote Desktop Services (RDS).  The Bicep deploys the required components for the PaaS service to operate and provide the required gateway into AVD