
$subID = "152aa2a3-2d82-4724-b4d5-639edab485af"
Set-AzContext -SubscriptionId $subID

New-AzResourceGroupDeployment -Name 'testdeployment' `
  -ResourceGroupName 'rg-mikestest' `
  -TemplateFile './scope.bicep' `
  -verbose `
  -Whatif

