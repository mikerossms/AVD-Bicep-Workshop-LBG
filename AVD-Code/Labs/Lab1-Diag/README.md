# Lab 1 - Diagnostics

The diagnostics lab is a simple bicep to introduce the concepts of bicep with a single component

The lab is split up into a number of exercises, each expanding on the previous one introducing new concepts

1. Exercise 1 - Simple resource deployment
1. Exercise 2 - Adding parameters
1. Exercise 3 - Variables and Outputs

## Deploying each exercise

```Powershell
cd Exercise<n>
.\deploy.ps1 -username '<your username>'
```

e.g.
```Powershell
cd Exercise1
.\deploy.ps1 -username 'tomsmith'
```

## What will happen

The deployment script will create a new resource group "rg-diag-uksouth-dev-[your unique id]" that will be visible in the portal containing a single Log Analytics Workspace

## Why do this?

Diagnostics is critical important in any environment looking at a wide range of metrics and information from thoughtput to threat actors.  On its own it does not do much, but as the course progresses you will see how diagnostics starts to link into the service you are building.