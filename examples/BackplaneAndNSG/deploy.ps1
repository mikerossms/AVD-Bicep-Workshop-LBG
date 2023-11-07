
$subID = "152aa2a3-2d82-4724-b4d5-639edab485af"
Set-AzContext -SubscriptionId $subID

$rgname = 'rg-miketest-backplane'
$location = 'uksouth'

#Create a resource group
New-AzResourceGroup -Name $rgname -Location $location

#Deploy the NSG
New-AzResourceGroupDeployment -Name 'Deploy NSG' `
  -ResourceGroupName $rgname `
  -TemplateFile './nsg.bicep' `
  -verbose `
  -Whatif


