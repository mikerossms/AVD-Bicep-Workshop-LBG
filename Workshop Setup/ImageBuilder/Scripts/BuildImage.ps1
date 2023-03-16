<#
.SYNOPSIS
Deploys the template and starts the build process

.DESCRIPTION
Deploys the BICEP image template and then, assuming that doBuildImage is set to $true (default), will then build out the image

.PARAMETER imageName
(Required) - The name of the Image AND Folder in which the image build scripts are deployed.  Images are created in the "Images" folder

.NOTES
It would be better if the bicep deployment was part of the pipeline and the outputs from it presented to this powershell script
This, can be done, but needs further research.
#>

param (
    [Parameter(Mandatory)]
    [String]$imageName,
    [String]$imageRG,
    [String]$subscriptionID,
    [String]$storageRepoName,
    [String]$storageRepoRG,
    [String]$localenv,
    [String]$location,
    [String]$workloadName,
    [String]$workloadNameShort,
    [String]$publisher,
    [String]$sequenceNum = "001",
    [Int]$ibTimeout = 120,
    [String]$ibVMSize = "Standard_D2s_v3",
    [int]$pollingTime = 60,
    [Bool]$doBuildimage = $true
)

#Install the AZ Imagebuilder module if it is not already installed
Write-Output "Checking for Image Builder Powershell Module"
$module = Get-Module -Name Az.ImageBuilder -ListAvailable
if (-not $module) {
    Write-Output "Module not found - Installing Image Builder Powershell Module"
    Install-Module Az.ImageBuilder -force -Scope CurrentUser -ErrorVariable modFail
    if ($modFail) {
        Write-Error "Unable to install Image Builder powershell module"
        exit 1
    }
}

#Check we are in the right subscription
$subID = (Get-AzContext).Subscription.Id

if ($subID -ne $subscriptionID) {
    Write-Output "Switching to subscription: $subscriptionID"
    Set-AzContext -SubscriptionId $subscriptionID
}

#Get the RG resource details
Write-Output "Checking for the existence of the Resource Group: '$imageRG'"
$rg = Get-AzResourceGroup -Name $imageRG

if (-Not $rg) {
    Write-Error "ERROR: Unable to find the Resource Group '$imageRG' - cannot deploy"
    exit 1
}

#Get the location from the RG if not specified
if (-not $location) {
    $location = $rg.Location
}

#Get the Tags from the RG
$imageTags = $rg.Tags

#Deploy the image template bicep
Write-Output "Deploying the Image Definition in preparation for building"
$defDeploy = $null

$out = New-AzSubscriptionDeployment -Name "DeployImageResources-$imageName" -Location $location -Verbose -TemplateFile "Images\$imageName\imagebuild.bicep" -ErrorVariable defDeploy -TemplateParameterObject @{
    location=$location
    tags=$imageTags
    localenv=$localenv
    workloadName=$workloadName
    workloadNameShort=$workloadNameShort
    publisher=$publisher
    sequenceNumber=$sequenceNum
    ibTimeout=$ibTimeout
    ibVMSize=$ibVMSize
    storageRepoName=$storageRepoName
    storageRepoRG=$storageRepoRG
    imageName=$imageName
    ibRegionReplication=@()
}

if ($defDeploy) {
    Write-Error "ERROR: Failed to deploy the Image Definition"
    exit 1
}

#Get the template name from the BICEP output (assuming it has deployed correctly)
$templateName = $out.Outputs.imageTemplateName.Value

if (-Not $templateName) {
    Write-Error "ERROR: The BICEP deployment has not returned the Image Template name"
    exit 1
}

#If all is good and doBuildImage is $true, then start building the image
if ($doBuildImage) {
    #Now start the process of building the image
    Write-Output ""
    Write-Output "The image is now building.  This might take a while."
    Write-Output " - This script will continue to poll the image to check on progress."
    Write-Output " - If you wish to check on the progress you can also use the following command (not if the pipeline fails, it will NOT stop the build):"
    Write-Output "    Get-AzImageBuilderTemplate -ImageTemplateName '$templateName' -ResourceGroupName '$imageRG' | Select-Object LastRunStatusRunState, LastRunStatusRunSubState, LastRunStatusMessage"
    Write-Output ""

    $start = Get-Date
    Write-Output "Build Started: $start"

    #Kick off the image builder
    Start-AzImageBuilderTemplate -ResourceGroupName $imageRG -Name $templateName -NoWait

    #while loop that will poll the get-azimagebuildertemplate command until ProvisioningState is Succeeded or Failed
    while ($true) {
        $count++
        $image = Get-AzImageBuilderTemplate -ImageTemplateName $templateName -ResourceGroupName $imageRG
        if ($image.LastRunStatusRunState -eq 'Succeeded') {
            Write-Output "Image build succeeded"
            break
        }
        elseif ($image.LastRunStatusRunState -eq 'PartiallySucceeded') {
            Write-Warning "The image built with issues.  Check the logs"
            break
        }
        elseif ($image.LastRunStatusRunState -eq 'Failed') {
            Write-Error "Image build failed"
            Write-Output " - Error Message: $($image.LastRunStatusMessage)"
            Write-Output " - Check the Storage account in the Staging RG for more information:"
            Write-Output "   - RG: $($image.ExactStagingResourceGroup)"
            break
        }
        else {
            $timespan = new-timespan -start $start -end (get-date)
            Write-Output "Image build is still running (Running for: $($timespan.Hours) hours, $($timespan.Minutes) minutes).  Polling again in $pollingTime seconds: $($image.LastRunStatusRunState) - $($image.LastRunStatusRunSubState)"
            Start-Sleep -Seconds $pollingTime
        }
    }
    $timespan = new-timespan -start $start -end (get-date)
    Write-Output "Image build ended after: $($timespan.Hours) hours, $($timespan.Minutes) minutes, $($timespan.Seconds) seconds"
} else {
    Write-Output "The image template was created, but the build itself was skipped"
    Write-Output "If you wish to run the build, you can use the following command:"
    Write-Output "Start-AzImageBuilderTemplate -ResourceGroupName '$imageRG' -Name '$templateName' -NoWait"
    Write-Output "You can then monitor it using command:"
    Write-Output "Get-AzImageBuilderTemplate -ImageTemplateName '$templateName' -ResourceGroupName '$imageRG' | Select-Object LastRunStatusRunState, LastRunStatusRunSubState, LastRunStatusMessage"
}

Write-Output "Completed"