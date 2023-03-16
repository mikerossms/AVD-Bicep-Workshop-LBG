<#
.SYNOPSIS
Image Builder Setup - Assign the UMI to the Compute gallery and storage account

.DESCRIPTION
This script will take the created UMI and apply the appropriate permissions to the Compute Gallery and Storage Account
#>

param (
    [String]$umiName = "umi-imagebuilder-prod-uksouth-001",
    [String]$umiRG,
    [String]$acgName,
    [String]$acgRG,
    [String]$repoName,
    [String]$repoRG,
    [String]$repoContainerScripts,
    [String]$repoContainerSoftware,
    [String]$subscriptionID
)

$roleACG = "Contributor"
$roleStorageScripts = "Storage Blob Data Contributor"
$roleStorageSoftware = "Storage Blob Data Reader"

#Check we are in the right subscription
$subID = (Get-AzContext).Subscription.Id

if ($subID -ne $subscriptionID) {
    Write-Output "Switching to subscription: $subscriptionID"
    Set-AzContext -SubscriptionId $subscriptionID
}

#check for the UMI existence
Write-Output "Checking for User Assigned Managed Identity '$umiName' in '$umiRG'"
$umiID = Get-AzUserAssignedIdentity -ResourceGroupName $umiRG -Name $umiName -ErrorAction SilentlyContinue

if (-Not $umiID) {
    Write-Error "ERROR - UMI not found ($umiName)"
    exit 1
}

############################
###Assign UMI to ACG Role###
############################
#Check if the ACG exists
Write-Output "Checking for Compute Gallery '$acgName' in '$acgRG'"
$acg = Get-AzGallery -ResourceGroupName $acgRG -Name $acgName -ErrorAction SilentlyContinue
if (-Not $acg) {
    Write-Error "ERROR - ACG not found ($acgName)"
    exit 1
}

#Get the ACG Scope
$acgScope = $acg.Id

#Check if the UMI is already assigned
Write-Output "Granting the Image Builder User Managed Identity access to the compute gallery ($acgName = $roleACG)"
$acgUMIAssigned = Get-AzRoleAssignment -ObjectId $umiId.PrincipalId -Scope $acgScope

#If not assigned, the assign it
if (-not $acgUMIAssigned) {
    Write-Output " - Assigning UMI Image Builder Role '$roleACG' to '$acgName'"
    New-AzRoleAssignment -ObjectId $umiId.PrincipalId -scope $acgScope -RoleDefinitionName $roleACG
}

##########################################
###Assign UMI to Storage Container Role###
##########################################

#Check if the storage account exists
Write-Output "Checking for Storage Account '$repoName' in '$repoRG'"
$st = Get-AzStorageAccount -ResourceGroupName $repoRG -Name $repoName -ErrorAction SilentlyContinue
if (-Not $st) {
    Write-Error "ERROR - Repo Storage Account not found ($repoName)"
    exit 1
}

#Get the ACG Scope
$stScope = $st.Id

#Check if the UMI is already assigned to the Scripts container
Write-Output "Granting the Image Builder User Managed Identity access to the storage account Scripts container ($repoName/$repoContainerScripts = $roleStorageScripts)"
$stUMIAssigned = Get-AzRoleAssignment -ObjectId $umiId.PrincipalId -Scope "$stScope/blobServices/$repoContainerScripts"

#If not assigned, the assign it
if (-not $stUMIAssigned) {
    Write-Output " - Assigning UMI Image Builder Role '$roleStorageScript' to '$repoName/$repoContainerScripts'"
    New-AzRoleAssignment -ObjectId $umiId.PrincipalId -scope "$stScope/blobServices/$repoContainerScripts" -RoleDefinitionName $roleStorageScripts
}


#Check if the UMI is already assigned to the Software container
Write-Output "Granting the Image Builder User Managed Identity access to the storage account Scripts container ($repoName/$repoContainerSoftware = $roleStorageSoftware)"
$stUMIAssigned = Get-AzRoleAssignment -ObjectId $umiId.PrincipalId -Scope "$stScope/blobServices/$repoContainerSoftware"

#If not assigned, the assign it
if (-not $stUMIAssigned) {
    Write-Output " - Assigning UMI Image Builder Role '$roleStorageScript' to '$repoName/$repoContainerSoftware'"
    New-AzRoleAssignment -ObjectId $umiId.PrincipalId -scope "$stScope/blobServices/$repoContainerSoftware" -RoleDefinitionName $roleStorageSoftware
}


#May need to grant reader role to the RG

Write-Output "Completed"