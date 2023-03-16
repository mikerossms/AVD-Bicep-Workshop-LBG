<#
.SYNOPSIS
Remove all the old image templates associated with this image

.DESCRIPTION
This simply takes the image name and the list of existing templates, then removes all templates that coinside with the name of the image.
This runs in the background so it does not delay the build.
#>

param (
    [Parameter(Mandatory)]
    [String]$imageName,
    [String]$imageBuilderRG,
    [String]$subscriptionID
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

#First remove any old image templates - keep things tidy
Write-Output "Removing the old templates for Image '$imageName' - this will run in the background"

#Clear out any previous build template to tidy up - only leave the one we have just created
#Get the list of image builder templates
$templates = Get-AzImageBuilderTemplate -ResourceGroupName $imageBuilderRG

#Loop through the templates and delete any that are not the current one - runs in the background
foreach ($template in $templates) {
    $templateImageName = (($template.Name).split('-')[0]).split('_')[-1]
    if ($templateImageName -eq $imageName.ToLower()) {
        Write-Output " - Deleting old template $($template.Name)"
        Remove-AzImageBuilderTemplate -ResourceGroupName $imageBuilderRG -Name $template.Name -NoWait
    }
}