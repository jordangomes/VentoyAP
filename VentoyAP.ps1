Write-Host "  _    __           __              ___    ____  "  -ForegroundColor Blue
Write-Host " | |  / /__  ____  / /_____  __  __/   |  / __ \ "  -ForegroundColor Blue
Write-Host " | | / / _ \/ __ \/ __/ __ \/ / / / /| | / /_/ / "  -ForegroundColor Blue
Write-Host " | |/ /  __/ / / / /_/ /_/ / /_/ / ___ |/ ____/  "  -ForegroundColor Blue
Write-Host " |___/\___/_/ /_/\__/\____/\__, /_/  |_/_/       "  -ForegroundColor Blue
Write-Host "                          /____/                 "  -ForegroundColor Blue
Write-Host "            Welcome to VentoyAP 1.0              "  -ForegroundColor Green

# Initialize variables
$VentoyPath = "$PSScriptRoot\ventoy"
$VentoyJson = "$VentoyPath\ventoy.json"
$AutoPilotPath = "$PSScriptRoot\AutoPilot"
$AutoPilotScriptPath = "$AutoPilotPath\Scripts"

Import-Module "$AutoPilotScriptPath\VentoyAPHelpers.psm1"

$AutoInstallISOs = Get-AutoInstalls -VentoyJson $VentoyJson
if ($AutoInstallISOs.Count -eq 0) {
    if (Test-Path $VentoyJson) {
        Write-Host "No auto-install ISOs found in ventoy.json lets set them up!"
    } else {
        Write-Host "No ventoy.json found, lets generate one"
    }
    
    $ISO = Select-ISO -BasePath $PSScriptRoot -VentoyJson $VentoyJson
    Write-Host "Selected ISO: $ISO"
} else {
    Write-Host "Auto-install ISOs found in ventoy.json:"
    $ISO = Select-ISO -BasePath $PSScriptRoot -VentoyJson $VentoyJson
    Write-Host "Selected ISO: $ISO"
}


Remove-Module VentoyAPHelpers
