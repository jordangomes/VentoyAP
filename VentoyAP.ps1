Write-Host "  _    __           __              ___    ____  "  -ForegroundColor Blue
Write-Host " | |  / /__  ____  / /_____  __  __/   |  / __ \ "  -ForegroundColor Blue
Write-Host " | | / / _ \/ __ \/ __/ __ \/ / / / /| | / /_/ / "  -ForegroundColor Blue
Write-Host " | |/ /  __/ / / / /_/ /_/ / /_/ / ___ |/ ____/  "  -ForegroundColor Blue
Write-Host " |___/\___/_/ /_/\__/\____/\__, /_/  |_/_/       "  -ForegroundColor Blue
Write-Host "                          /____/                 "  -ForegroundColor Blue
Write-Host "            Welcome to VentoyAP 1.0              "  -ForegroundColor Green

# Initialize variables
$VentoyPath = "$PSSriptRoot\ventoy"
$VentoyJson = "$VentoyPath\ventoy.json"
$AutoPilotPath = "$PSSriptRoot\AutoPilot"
$AutoPilotScriptPath = "$AutoPilotPath\Scripts"
$ISOPath = "$PSSriptRoot"

Import-Module "$AutoPilotScriptPath\VentoyAPHelpers.psm1"

# Find all ISO files in the current directory
$ISOFiles = Get-ChildItem -Path $ISOPath -Filter *.iso
if ($ISOFiles.Count -eq 0) {
    Write-Host "No ISO files found in the current directory. Exiting.." -ForegroundColor Yellow
    Exit
}

# Check congig for auto-install ISOs
if (Test-Path $VentoyJson) {
    $ConfigExists = $TRUE
    $VentoyJsonContent = Get-Content $VentoyJson | ConvertFrom-Json -ErrorAction Stop
    $AutoInstallISOs = $VentoyJsonContent.auto_install
    
} else {
    $ConfigExists = $FALSE
    $AutoInstallISOs = @()
}

if ($AutoInstallISOs.Count -eq 0) {
    if($ConfigExists) {
        Write-Host "No auto-install ISOs found in ventoy.json lets set them up!"
    } else {
        Write-Host "No ventoy.json found, lets generate one"
    }
    
    $ISO = Select-ISO -AutoInstallISOs $AutoInstallISOs -ISOFiles $ISOFiles -BasePath $PSScriptRoot
    Write-Host "Selected ISO: $ISO"
} else {
    Write-Host "Auto-install ISOs found in ventoy.json:"
    $ISO = Select-ISO -AutoInstallISOs $AutoInstallISOs -ISOFiles $ISOFiles -BasePath $PSScriptRoot
    Write-Host "Selected ISO: $ISO"
}

