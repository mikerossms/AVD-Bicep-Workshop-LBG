<#
This script deploys teh workshop AVD using the code base from "FullCode".  the only change is the provision of providing a custom image rather than
a fixed image, some schedules for the scaler and a larger VM size
#>

$dologin = $false
$subID = "152aa2a3-2d82-4724-b4d5-639edab485af"

#Login to azure (if required) - if you have already done this once, then it is unlikley you will need to do it again for the remainer of the session
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $subID
} else {
    Write-Warning "Login skipped"
}

#check that the subscription ID we are connected to matches the one we want and change it to the right one if not
Write-Host "Checking we are connected to the correct subscription (context)" -ForegroundColor Green
if ((Get-AzContext).Subscription.Id -ne $subID) {
    #they dont match so try and change the context
    Write-Warning "Changing context to subscription: $subID"
    $context = Set-AzContext -SubscriptionId $subID

    if ($context.Subscription.Id -ne $subID) {
        Write-Error "ERROR: Cannot change to subscription: $subID"
        exit 1
    }

    Write-Host "Changed context to subscription: $subID" -ForegroundColor Green
}


$acgName = "acg_imagebuilder_dev_uksouth_001"
$imageName = "LBG"
$imageRg = "rg-imagebuilder-dev-uksouth-001"
$scalerRg = "rg-avd-uksouth-dev-wshop"

#Get the ACG image ID
#Get-AzImage -ResourceGroupName $imageRG -ImageName $imageName
$imageID = (Get-AzGalleryImageDefinition -ResourceGroupName $imageRG -GalleryName $acgName -GalleryImageDefinitionName $imageName).Id

$imageObject = @{
    id = $imageID
}

Write-Host "Deploying AVD workspace with image id: $imageID"

Write-Host "Deploying the workshop AVD" -ForegroundColor Green
&..\..\AVD-Code\FullCode\Script\deploy.ps1 `
    -uniqueIdentifier "wshop" `
    -location "uksouth" `
    -localEnv "dev" `
    -subID $subID `
    -workloadNameAVD "avd" `
    -workloadNameDiag "diag" `
    -avdVnetCIDR "10.200.0.0/24" `
    -vmHostSize "Standard_E4as_v5" `
    -numberOfHostsToDeploy 4 `
    -imageToDeploy $imageObject `
    -storageAccountType 'Premium_LRS' `
    -dologin $false `
    -updateVault $false

#Update the scaling plan
Write-Host "Updating the scaling plan" -ForegroundColor Green
New-AzResourceGroupDeployment `
    -Name "Deploy-ScalingSchedule" `
    -ResourceGroupName $scalerRg `
    -TemplateFile ".\updateScaler.bicep" `
    -Verbose `
    -TemplateParameterObject @{
        hostPoolScalePlanName='vdscaling-avd-uksouth-dev-wshop'
    }