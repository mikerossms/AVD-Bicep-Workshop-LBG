# Setting up a new Image

Images are set up by simply duplicating and making adjustments to the "Template-Windows" or "Template-Ubuntu" folders.  See the deails below for each type.

It is assumed that the Agent you will be using is Powershell based and as the Azure Powershell components installed in order to build the image.  If you are using an Azure supplied agent, then this is already included.  If you are using a stand alone agent, however, e.g. VMSS based, this needs to either be in the pipeline, or better, included in the image that the agent uses as it is significently more efficient doing it hat way.

## Windows Images

Starting with the YAML file - "ib-buildimage-pipeline.yml", please make sure that the **Pool** setting is correct.  By default this is set to "Azure Pipelines", however this can be changed to any pool as per your requirements.

### Variables
- IMAGE NAME
    - This is the name of the folder created to contain the image e.g. Core, Analyst.  This name is then used as the name of the image itself and is used throughout the image building process.  This is mandatory as it gets passed into the scripts and subsequently the bicep.
- SUBSCRIPTION ID
    - This is the subscription used for the image builder, storage repo and image gallery.  By default this is sued for each step in the YAML, however, this is not mandatory as each step can technically run in different subscriptions, so this could be expanded as required.
- RG OF COMPUTE GALLERY
    - This is RG where the image builder will find the compute gallery so it has somewhere to put the images

Note: These can, of course, be removed from the YAML and added as variables to the Pipeline GUI in Azure DevOps.

There are no further mandatory changes needed.

### imagebuild.bicep

This script is called by the "BuildImage.ps1" script.  for the moment only the parameters provided as variables above are passed in and the rest are as defaults within the BICEP code.  this will be updated in due course.

Listed below are the parameters you are most likley to need to change (defaults in brackets).  It should be noted that this WILL pick up the name of the image and apply it accordingly to the resources.

**General**

- localenv (prod)
    - The local environment name
- location (uksouth)
    - the location where the resources will be deployed
- workloadNameShort (IB)
    - a short name (4 chars max) that can be used to identify the workload - used to help keep resource names now in size
- workloadName (ImageBuilder)
    - the name of the workload being deployed
- publisher (AVDSquad)
    - who the compute gallery published is
- tags (see bicep)
    - a list of common tags to apply to the resource.  Many are based on the variables above, but there are also some static entries to check

**Image Builder Specific**

- ibTimeout (120)
    - The amount of time given to Image Builder before it times out on the build
- ibVMSize (Standard_D2s_v3)
    - The size of the VM used to actually build the image (not the one that is deployed for users)
- ibRegionReplication (RG Location, "west europe")
    - Where you want the image replicated to.  By default it is the same location as the resource group, plus West Europe
- ibSourceImage (win11-22h2-avd-m365)
    - A object that contains the source image that ImageBuilder starts with.  By default it is the latest Windows 11 build with O365

**Customization Steps**

The Bicep Section "customizationSteps" contains the steps used to customise the image.  there is normally no requirement to edit this section as the "installSoftware.ps1" handles the installations, however if additional steps are required to further customise the image, this is where they are added.  An example is where a piece of software is required as part of the build and it must have a restart after it is installed before it can be used by the rest of the build.

### InstallSoftware.ps1

This script provides the meat and bones of the installation.  This is where all the software required by the image is installed.  The script itself is fleshed out with commented examples.  Use those examples to do any of the following:

- Install an executable from the local storage repository
    - Install MSI
    - Install EXE
    - Install VSIX

- From Winget (windows 11 only)
    - Install a single package
    - Install from an JSON package list downloaded from the local storage repository

- From Chocolatey
    - Install a single package
    - Install from an XML package list downloaded from the local storage repository

- Install Python packages
    - Install a single PIP file (not it will install pip is required)
    - Install a python package list (TXT file) downloaded from the local storage repository

- Other functions
    - Copy and unzip files from the local storage repository into a local location
    - Update a registry entry
    - Install a powershell module
    - Install a windows capability (e.g. RSAT tools)

If you are installing anything from the local repository, pass in a path like this "ContainerFolderName/ThingToInstall". e.g. "TestSoftware\ChocoPackages.config"  This will go to the storage account blob container containing the software (default is softeware) then to the container folder "TestSoftware" to find the file "ChocoPackages.config".  The location of the software is image agnostic, so software can be shared between images.

You must, of course, upload the software/scripts/files for the image builder to find otherwise the build will fail.

*Note:*  you can also simply add powershell to this script as well, for any custom deployments.

### ValidateEnvironment.ps1

This is a script that is custom to the image.  It is used as an automation step to validate that the image has built as expected.  This script can contain any test to be run on the image at the end of the building process.  By default the validation script does not actually do any validion, but does come with a couple of examples of how to use the Test-Command function to check software has installed.

This script is up to you.

## Ubuntu Images

To be done