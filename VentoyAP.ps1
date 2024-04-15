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

function Get-AutoInstallMenu {
    param (
        [Parameter(Mandatory=$TRUE)]$ISO
    )
    while ($true) {
        $UnattendFiles = Get-ChildItem -Path $AutoPilotPath -Filter *.xml
        if ($UnattendFiles.Count -eq 0) {
            $addAPProfile = Read-Host "No AutoPilot Profiles found, would you like to add one? (y/n)"
            Write-Host ""

            if($addAPProfile -eq "y") {
                New-APProfile -AutoPilotPath $AutoPilotPath
            } elseif($addAPProfile -eq "n") {
                break
            }
        } else {
            $AutoInstalls = Get-AutoInstalls -VentoyJson $VentoyJson -ISO $ISO
            $i = 0;
            foreach($UnattendFile in $UnattendFiles) {
                $i++
                $active = $AutoInstalls.template -contains "/AutoPilot/$($UnattendFile.Name)"
                if($active) {
                    Write-Host "$i - $($UnattendFile.Name) - Active" -ForegroundColor Green
                } else {
                    Write-Host "$i - $($UnattendFile.Name)"
                }
            }
            $profile = Read-Host "Select a profile to add/remove (1-$($UnattendFiles.Count)), enter n for new or enter b to go back"
            Write-Host ""

            try {
                $numInput = [int]$profile
            } catch {
                $numInput = 0
            }
            if([int]$numInput -ge 1 -and [int]$profile -le $UnattendFiles.Count) {
                $UnattendFile = $UnattendFiles[$numInput - 1]
                $active = $AutoInstalls.template -contains "/AutoPilot/$($UnattendFile.Name)"
                if($active){
                    Write-Host "Removing AutoInstall $($UnattendFile.Name) for $ISO" -ForegroundColor Red
                    Remove-AutoInstall -VentoyJson $VentoyJson -ISO $ISO -UnattendFile $UnattendFile.Name
                } else {
                    Write-Host "Adding AutoInstall $($UnattendFile.Name) for $ISO" -ForegroundColor Green
                    Add-AutoInstall -VentoyJson $VentoyJson -ISO $ISO -UnattendFile $UnattendFile.Name
                }
            } elseif ($profile -eq "n") {
                New-APProfile -AutoPilotPath $AutoPilotPath
            }elseif($profile -eq "b") {
                break
            }
        }
    }

}

function Get-MainMenu {
    while ($TRUE) {
        $ISO = Select-ISO -BasePath $PSScriptRoot -VentoyJson $VentoyJson
        Write-Host "Selected ISO: $ISO" -ForegroundColor Green
        Get-AutoInstallMenu -ISO $ISO
    }
}

$AutoInstallISOs = Get-AllAutoInstalls -VentoyJson $VentoyJson
if ($AutoInstallISOs.Count -eq 0) {
    if (Test-Path $VentoyJson) {
        Write-Host "No auto-install ISOs found in ventoy.json lets set them up!"
    } else {
        Write-Host "No ventoy.json found, lets generate one"
    }
    Get-MainMenu
} else {
    Write-Host "Auto-install ISOs found in ventoy.json:"
    Get-MainMenu
}

Remove-Module VentoyAPHelpers
