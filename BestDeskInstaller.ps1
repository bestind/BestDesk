$ErrorActionPreference= 'silentlycontinue'
#Run as administrator and stays in the current directory
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
        Exit;
    }
}
# Replace rd.bestind.xyz and ONYTRe80OdmHvkDB5L1yxfUViJajCN6MlPWx4+xuu1g= with the relevant info for your install. IE rd.bestind.xyz becomes your rustdesk server IP or DNS and ONYTRe80OdmHvkDB5L1yxfUViJajCN6MlPWx4+xuu1g= becomes your public key.

$rustdesk_url = 'https://github.com/rustdesk/rustdesk/releases/latest'
$request = [System.Net.WebRequest]::Create($rustdesk_url)
$response = $request.GetResponse()
$realTagUrl = $response.ResponseUri.OriginalString
$rustdesk_version = $realTagUrl.split('/')[-1].Trim('v')
Write-Output("Installing Rustdesk version $rustdesk_version")

function OutputIDandPW([String]$rustdesk_id, [String]$rustdesk_pw) {
  Write-Output("######################################################")
  Write-Output("#                                                    #")
  Write-Output("# CONNECTION PARAMETERS:                             #")
  Write-Output("#                                                    #")
  Write-Output("######################################################")
  Write-Output("")
  Write-Output("  RustDesk-ID:       $rustdesk_id")
  Write-Output("  RustDesk-Password: $rustdesk_pw")
  Write-Output("")
}

If (!(Test-Path $env:Temp)) {
  New-Item -ItemType Directory -Force -Path $env:Temp > null
}

If (!(Test-Path "$env:ProgramFiles\Rustdesk\RustDesk.exe")) {

  cd $env:Temp

  If ([Environment]::Is64BitOperatingSystem) {
    $os_arch = "x64"
  } Else {
    $os_arch = "x32"
  }

  Invoke-WebRequest https://github.com/rustdesk/rustdesk/releases/download/$rustdesk_version/rustdesk-$rustdesk_version-windows_$os_arch.zip -Outfile rustdesk.zip

  Expand-Archive rustdesk.zip
  cd rustdesk
  Start-Process "rustdesk-$rustdesk_version-putes.exe" -argumentlist "--silent-install" -wait

  # Set URL Handler
  New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk" > null
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk" -Name "(Default)" -Value "URL:RustDesk Protocol" > null
  New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk" -Name "URL Protocol" -Type STRING > null

  New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\DefaultIcon" > null
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk\DefaultIcon" -Name "(Default)" -Value "RustDesk.exe,0" > null

  New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell" > null
  New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell\open" > null
  New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell\open\command" > null
  $rustdesklauncher = '"' + $env:ProgramFiles + '\RustDesk\RustDeskURLLauncher.exe" %1"'
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell\open\command" -Name "(Default)" -Value $rustdesklauncher > null

  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force > null
  Install-Module ps2exe -Force > null

$urlhandler_ps1 = @"
  `$url_handler = `$args[0]
  `$rustdesk_id = `$url_handler -creplace '(?s)^.*\:',''
  Start-Process -FilePath '$env:ProgramFiles\RustDesk\rustdesk.exe' -ArgumentList "--connect `$rustdesk_id"
"@

  New-Item "$env:ProgramFiles\RustDesk\urlhandler.ps1" > null
  Set-Content "$env:ProgramFiles\RustDesk\urlhandler.ps1" $urlhandler_ps1 > null
  Invoke-Ps2Exe "$env:ProgramFiles\RustDesk\urlhandler.ps1" "$env:ProgramFiles\RustDesk\RustDeskURLLauncher.exe" > null

  # Cleanup Tempfiles
  Remove-Item "$env:ProgramFiles\RustDesk\urlhandler.ps1" > null
  cd $env:Temp
  Remove-Item $env:Temp\rustdesk -Recurse > null
  Remove-Item $env:Temp\rustdesk.zip > null
}

# Write config
$RustDesk2_toml = @"
rendezvous_server = 'rd.bestind.xyz'
nat_type = 1
serial = 0

[options]
custom-rendezvous-server = 'rd.bestind.xyz'
key =  'ONYTRe80OdmHvkDB5L1yxfUViJajCN6MlPWx4+xuu1g='
relay-server = 'rd.bestind.xyz'
api-server = 'https://rd.bestind.xyz'
enable-audio = 'N'
"@

If (!(Test-Path $env:AppData\RustDesk\config\RustDesk2.toml)) {
  New-Item $env:AppData\RustDesk\config\RustDesk2.toml > null
}
Set-Content $env:AppData\RustDesk\config\RustDesk2.toml $RustDesk2_toml > null

If (!(Test-Path $env:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml)) {
  New-Item $env:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml > null
}
Set-Content $env:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml $RustDesk2_toml > null

$random_pass = (-join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_}))
Start-Process "$env:ProgramFiles\RustDesk\RustDesk.exe"  -argumentlist "--password $random_pass" -wait

# Get RustDesk ID
If (!("$env:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml")) {
  $rustdesk_id = (Get-Content $env:AppData\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("id") })
  $rustdesk_id = $rustdesk_id.Split("'")[1]
  $rustdesk_pw = (Get-Content $env:AppData\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("password") })
  $rustdesk_pw = $rustdesk_pw.Split("'")[1]
  Write-Output("Config file found in user folder")
  OutputIDandPW $rustdesk_id $rustdesk_pw
} Else {
  $rustdesk_id = (Get-Content $env:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("id") })
  $rustdesk_id = $rustdesk_id.Split("'")[1]
  $rustdesk_pw = (Get-Content $env:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("password") })
  $rustdesk_pw = $rustdesk_pw.Split("'")[1]
  Write-Output "Config file found in windows service folder"
  OutputIDandPW $rustdesk_id $rustdesk_pw
}

Stop-Process -Name RustDesk -Force > null
Start-Service -Name RustDesk > null
