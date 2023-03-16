$url = "https://api.github.com/repos/powershell/powershell/releases/latest"

$request = Invoke-WebRequest -Uri $url
$release = ($request.Content | ConvertFrom-Json)
$version = $release.tag_name

Write-Output "The latest version of PowerShell 7 is $version"

$OSArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
$versionNumber = $version.Split('v')[-1]
$installerUrl = "https://github.com/PowerShell/PowerShell/releases/download/$version/PowerShell-$versionNumber-win-$OSArch.msi"

Write-Output "The installer URL is $installerUrl"

$msifile = ($installerUrl.Split('/'))[-1]
$file = "$env:TEMP\$msifile"
Write-Output "Downloading to: $file"
Invoke-WebRequest -Uri $installerUrl -OutFile $file