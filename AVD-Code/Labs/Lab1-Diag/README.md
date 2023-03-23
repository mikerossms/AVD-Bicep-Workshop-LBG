# Lab 1 - Diagnostics

This lab is a walkthrough of a complete Bicep file and deploy.ps1 script

## Deploying the Lab

```Powershell
cd Scripts
.\deploy.ps1 -uniqueIdentifier "Unique identifier provided by instructor"
```

## What will happen

The deployment script will create a new resource group "rg-diag-uksouth-dev-[your unique id]" that will be visible in the portal containing a single Log Analytics Workspace

## Why do this?

Diagnostics is critical important in any environment looking at a wide range of metrics and information from thoughtput to threat actors.  On its own it does not do much, but as the course progresses you will see how diagnostics starts to link into the service you are building.