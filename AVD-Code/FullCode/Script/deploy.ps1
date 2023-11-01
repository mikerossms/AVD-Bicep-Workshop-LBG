<#
.SYNOPSIS
Deploys the bicep code to the subscription.

.DESCRIPTION
This script deploys all the required code necessary in order to deploy the fully working AVD.  this includes:
- Diagnostics
- Infrastructure
- Hosts

It is also responsible for adding a user to the Application Group and changing the name of the remote desktop.
#>

#Get the runtime parameters from the user.  You will need to change the "uniqueIdentifier" for each user to avoid clashes
param (
    [String]$uniqueIdentifier = "full",
    [String]$location = "uksouth",
    [String]$localEnv = "dev",
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [String]$workloadNameAVD = "avd",
    [String]$workloadNameDiag = "diag",
    [String]$avdVnetCIDR = "10.140.0.0/24",
    [String]$vmHostSize = "Standard_D2s_v3",
    [String]$storageAccountType = "StandardSSD_LRS",
    [Int]$numberOfHostsToDeploy = 1,
    [Object]$imageToDeploy = @{},
    [String]$domainOUPath = "OU=AADDC Computers,DC=quberatron,DC=com",
    [Bool]$dologin = $true,
    [Bool]$useCentralVMJoinerPwd = $true,
    [Bool]$updateVault = $true
)

if (-not $uniqueIdentifier) {
    Write-Error "A unique identifier MUST be specified.  Always use the same identifier for EVERY deployment"
    exit 1
}

#Define the name of both the diagnostic and AVD deployment RG
$avdRGName = "rg-$workloadNameAVD-$location-$localEnv-$uniqueIdentifier"
$diagRGName = "rg-$workloadNameDiag-$location-$localEnv-$uniqueIdentifier"

#Leave these settings as they are - they set up the connection and access to the domain.
$domainName = "quberatron.com"
$domainAdminUsername = "vmjoiner@$domainName"
$localAdminUsername = "localadmin"

#Keyvault and secret location for the VM Joiner Password
$domainKeyVaultName = "kv-entrads"
#$domainKeyVaultRG = "RG-EntraDomainServices"
#$domainKeyVaultSub = "ea66f27b-e8f6-4082-8dad-006a4e82fcf2"
$domainVMJoinerSecretKey = "domainjoiner"

#Configure the domain and local admin passwords
#Note: Setting them to a string is required as we are passing in a secure() string to the bicep code and it must be converted to a secure string in powershell
#and secure string cannot be blank
$domainAdminPassword = ConvertTo-SecureString -String 'noupdate' -AsPlainText -Force
$localAdminPassword = ConvertTo-SecureString -String 'noupdate' -AsPlainText -Force

#Configure the networking for this instance of AVD.
#$avdVnetCIDR = "10.200.1.0/24" - now set in the parameters
$avdSnetCIDR = $avdVnetCIDR

#Configure the DNS servers to use for this service - These are static and point to the already deployed Entra DS, so will not need to change
$adServerIPAddresses = @(
  '10.99.99.4'
  '10.99.99.5'
)

#Set up some basic tags to attach to resources
$tags = @{
    Environment=$localEnv
    Owner="LBG"
}

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

#while we have created placeholders above for the admin passwords, this next code provides a means to actually get the real passwords and add them to the keyvault
#Get the new admin passwords and update/create the vault if required otherwise skip this.
if ($updateVault) {
    Write-Warning "They KeyVault and its admin passwords will be updated (or created if they don't exist)"
    Write-Warning 'If you dont want to do this, press Ctrl+C twice, add "-updateVault $false" to the script parameters and run again'
    if ($useCentralVMJoinerPwd) {
        Write-Host "Getting the VMJoiner password from the Central Entra DS vault"
        #Get the secret from the Azure central Entra AD Keyvault
        $domainVMJoinerSecret = Get-AzKeyVaultSecret -VaultName $domainKeyVaultName -Name $domainVMJoinerSecretKey -AsPlainText -ErrorAction SilentlyContinue
        if (-not $domainVMJoinerSecret) {
            Write-Error "ERROR: Unable to get the VMJoiner password from the central Entra DS KeyVault"
            exit 1
        }
        $domainAdminPassword = ConvertTo-SecureString -String $domainVMJoinerSecret -AsPlainText -Force
    
    } else {
        $domainAdminPassword = Read-Host -Prompt "Enter the password for the Domain VMJoiner account" -AsSecureString
    }
    $localAdminPassword = Read-Host -Prompt "Enter the Local Admin password to use on each host" -AsSecureString
} else {
    Write-Warning "Password setting skipped - using existing values in keyvault.  Vault will not be updated"
}


#Create a resource group for the diagnostic resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $diagRGName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $diagRGName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $diagRGName -Location $location)) {
        Write-Error "ERROR: Cannot create Resource Group: $diagRGName"
        exit 1
    }
}

#Deploy the diagnostic.bicep code to that RG we just created
Write-Host "Deploying diagnostic.bicep to Resource Group: $diagRGName" -ForegroundColor Green
$diagOutput = New-AzResourceGroupDeployment -Name "Deploy-Diagnostics" -ResourceGroupName $diagRGName -TemplateFile "$PSScriptRoot/../Bicep/Diagnostics/diagnostics.bicep" -Verbose -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    tags=$tags
    workloadName=$workloadNameDiag
    uniqueName=$uniqueIdentifier
}

if (-not $diagOutput ) {
    Write-Error "ERROR: Cannot deploy diagnostic.bicep to Resource Group: $diagRGName"
    exit 1
}


#Create a resource group for the AVD resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $avdRGName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $avdRGName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $avdRGName -Location $location)) {
        Write-Error "ERROR: Cannot create Resource Group: $avdRGName"
        exit 1
    }
}

# Get the Azure Username of the user currently logged in and running this script
$currentUser = (Get-AzContext | Select-Object -ExpandProperty Account).Id

# Get the ID of this user from Azure AD
$currentUserId = (Get-AzADUser -UserPrincipalName $currentUser).Id

#Deploy the AVD backplane bicep code which includes the networks, keyvault, hostpool, app grup and worspace.
#the user deploying this script is also then added to the App Group as a user
Write-Host "Deploying Infrastructure (backplane.bicep) to Resource Group: $avdRGName" -ForegroundColor Green
$backplaneOutput = New-AzResourceGroupDeployment -Name "Deploy-Backplane" `
 -ResourceGroupName $avdRGName `
 -TemplateFile "$PSScriptRoot/../Bicep/Infrastructure/backplane.bicep" `
 -domainAdminPassword $domainAdminPassword `
 -localAdminPassword $localAdminPassword `
 -Verbose `
 -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    uniqueName=$uniqueIdentifier
    tags=$tags
    workloadName=$workloadNameAVD
    rgDiagName=$diagRGName
    lawName=$diagOutput.Outputs.lawName.Value
    domainName=$domainName
    avdVnetCIDR=$avdVnetCIDR
    avdSnetCIDR=$avdSnetCIDR
    adServerIPAddresses=$adServerIPAddresses
    deployVault=$updateVault
    appGroupUserID=$currentUserId
}

if (-not $backplaneOutput.Outputs.hpName.Value) {
    Write-Error "ERROR: Failed to deploy BackPlane to Resource Group: $avdRGName"
    exit 1
}


#Change the name of the "SessionDesktop" to be something more helpful (advanced, not required)
#Basically, when you use Bicep or ARM to deploy the application group there is no option to change the name of the Session Desktop to
#something more helpful.  so if you have a lot of desktops, it can get really confusing.  It can, of course, be changed
#in the portal, but the only way to do it programatically is to use the Azure REST API

Write-Host "Changing the name of the Application Group Session Desktop to something more useful" -foregroundColor Green
$accessToken = (Get-AzAccessToken).Token
$headers = @{
    Authorization = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}
$url = "https://management.azure.com/subscriptions/$subId/resourceGroups/$avdRGName/providers/Microsoft.DesktopVirtualization/applicationGroups/$($backplaneOutput.Outputs.appGroupName.Value)/desktops/SessionDesktop?api-version=2022-09-09"
$newSessionDesktopName = "Desktop ($currentUser)"
$content = @{
    properties = @{
        friendlyName = "$newSessionDesktopName"
    }
} | ConvertTo-Json
$restOutput = Invoke-RestMethod -Method Patch -Uri $url -Body $content -Headers $headers

if (-Not $restOutput) {
    Write-Warning "Unable to change the name of the Session Desktop."
}

#The next step is to build the hosts and add them to both the AD and the HostPool.  While this could be done in the 
#backplane.bicep file, it is usually better to pull this into its own deployment.  why?  Because you are highly likley to need
#to deploy additional hosts at a later date and you dont want to have to redeploy the entire backplane.

#First we need to get the hostpool and generate a new registration token.  This token is required to add the Host to the Pool
#and is "baked into" the host when it is build though an extension.  The token is only valid for a short period of time, enough
#to add the host to the pool.  Once in the pool the registration token is no longer required.
#Minimum is 1 hours, maximum is 30 days.  Typically set around 2 hours (or more if deploying lots of hosts)
Write-Host "Generating a new hostpool registration token" -ForegroundColor Green
$expiryTime = $((Get-Date).ToUniversalTime().AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
$hpToken = (New-AzWvdRegistrationInfo -HostPoolName $backplaneOutput.Outputs.hpName.Value -ResourceGroupName $avdRGName -ExpirationTime $expiryTime).token

if (-not $hpToken) {
    Write-Error "ERROR: Unable to generate a new host pool token"
    exit 1
}

#Deploy the hosts and attach them to AADDS and the hostpool
Write-Host "Deploying/Updating Hosts (deployHosts.bicep) to Resource Group: $avdRGName" -ForegroundColor Green
$buildHostOutput = New-AzResourceGroupDeployment -Name "Deploy-Hosts" `
 -ResourceGroupName $avdRGName `
 -TemplateFile "$PSScriptRoot/../Bicep/Hosts/deployHosts.bicep" `
 -Verbose `
 -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    uniqueName=$uniqueIdentifier
    tags=$tags
    workloadName=$workloadNameAVD
    domainName=$domainName
    domainAdminUsername=$domainAdminUsername
    domainOUPath=$domainOUPath
    localAdminUsername=$localAdminUsername
    numberOfHostsToDeploy=$numberOfHostsToDeploy
    hostPoolName=$backplaneOutput.Outputs.hpName.Value
    hostPoolToken=$hpToken
    subnetID=$backplaneOutput.Outputs.subNetId.Value
    keyVaultName=$backplaneOutput.Outputs.keyvaultName.Value
    vmSize=$vmHostSize
    vmImageObject=$imageToDeploy
    storageAccountType=$storageAccountType
}

if (-not $buildHostOutput) {
    Write-Error "Host Deployment Failed"
    exit 1
}

Write-Host "Finished Deployment" -ForegroundColor Green
Write-Host "---"
Write-Host "What next?"
Write-Host "1: Make sure you have been added to the Application Group and add any other Users or Groups"
Write-Host "2: Check that the hosts appear in the Host Pool"
Write-Host "3: Access the AVD environment via the web (https://client.wvd.microsoft.com/arm/webclient/index.html)"
Write-Host "---"