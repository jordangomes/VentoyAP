#region Startup
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

#Import Modules
Import-Module "$AutoPilotScriptPath\VentoyAPHelpers.psm1"
Import-Module "$AutoPilotScriptPath\PowerInput.psm1"

Start-Sleep 3
#endregion

#region Menus
function Get-MainMenu {
    while ($TRUE) {
        $ISOs = Get-ISOs -BasePath $PSScriptRoot
        $selectedISO = Get-ListSelection -Title "Select an ISO to configure AutoPilot for" -Items $ISOs.Name -AllowCancel
        if ($null -eq $selectedISO) {
            Write-Host "Exitting..."
            exit
        } else {
            $ISO = $ISOs[$selectedISO]
            Write-Host "Selected ISO: $ISO" -ForegroundColor Green
            Get-AutoInstallMenu -ISO $ISO
        }
        
    }
}

function Get-AutoInstallMenu {
    param (
        [Parameter(Mandatory=$TRUE)]$ISO
    )
    while ($true) {
        $UnattendFiles = Get-ChildItem -Path $AutoPilotPath -Filter *.xml
        if ($UnattendFiles.Count -eq 0) {
            $addAPProfile = Get-ListSelection -Title "No AutoPilot profiles found, would you like to create one?" -Items "Yes","No"

            if($addAPProfile -eq 0) {
                New-APProfile
            } else {
                break
            }
        } else {
            $addAPProfile = Get-ListSelection -Title "What would you like to do with $($ISO.Name)?" -Items "Assign/Unassign AutoPilot Profile","Create a new AutoPilot Profile" -AllowCancel

            if($null -eq $addAPProfile) {
                break
            } elseif ($addAPProfile -eq 1) {
                New-APProfile
            } else {
                $AutoInstalls = Get-AutoInstalls -VentoyJson $VentoyJson -ISO $ISO.Name
                $i = 0;
                $PreselectedItems = @()
                foreach($UnattendFile in $UnattendFiles) {
                    if($AutoInstalls.template -contains "/AutoPilot/$($UnattendFile.Name)") {
                        $PreselectedItems += $i
                    }
                    $i++
                }

                $selectedProfiles = Get-ListMultipleSelection -Title "Use space to select profiles for $($ISO.Name)" -Items $UnattendFiles.Name -PreselectedItems $PreselectedItems -AllowCancel -AllowNone

                if($null -ne $selectedProfiles) {
                    for ($i = 0; $i -lt $UnattendFiles.Count; $i++) {
                        $UnattendFile = $UnattendFiles[$i]
                        $active = $AutoInstalls.template -contains "/AutoPilot/$($UnattendFile.Name)"
                        if($active -and $selectedProfiles -notcontains $i) {
                            Write-Host "Removing AutoInstall $($UnattendFile.Name) for $($ISO.Name)" -ForegroundColor Red
                            Remove-AutoInstall -VentoyJson $VentoyJson -ISO $ISO.Name -UnattendFile $UnattendFile.Name
                        } 
                        if(-not $active -and $selectedProfiles -contains $i){
                            Write-Host "Adding AutoInstall $($UnattendFile.Name) for $($ISO.Name)" -ForegroundColor Green
                            Add-AutoInstall -VentoyJson $VentoyJson -ISO $ISO.Name -UnattendFile $UnattendFile.Name
                        }
                    }
                } else {
                    break
                }
            }
        }
    }
}

function New-APProfile {
    Clear-Host
    while ($true) {
        $APProfileName = Read-Host "Enter the name of the new AutoPilot profile"
        if($APProfileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ne -1) {
            Write-Host "Profile name can only contain characters that can be used in a file name" -ForegroundColor Red
            continue
        }
        $APProfilePath = Join-Path -Path $AutoPilotPath -ChildPath "$APProfileName.xml"
        if(Test-Path $APProfilePath) {
            Write-Host "Profile already exists, please choose a different name" -ForegroundColor Red
            continue
        }
        break
    }
    while ($true) {
        $languageSelection = @{}
        $locales = Import-Csv "$AutoPilotPath\Scripts\locales.csv"
        $systemLocales = $locales | Where-Object { $_.System -eq "Yes" }

        $InputLocale = Search-List -Prompt "Please search for a input language e.g. English (Australia)" -Items $locales.LanguageName
        $languageSelection.Add("InputLocale", $locales[$InputLocale].Code)

        $UILanguage = Search-List -Prompt "Please search for a UI Language e.g. English" -Items $systemLocales.LanguageName
        $languageSelection.Add("UILanguage", $systemLocales[$UILanguage].BCP47tag)
    
        $SystemLocale = Search-List -Prompt "Please search for a System Locale e.g. English" -Items $systemLocales.LanguageName
        $languageSelection.Add("SystemLocale", $systemLocales[$SystemLocale].BCP47tag)

        $SystemLocaleFallback = Search-List -Prompt "Please search for a System Locale e.g. English" -Items $systemLocales.LanguageName
        $languageSelection.Add("SystemLocaleFallback", $systemLocales[$SystemLocaleFallback].BCP47tag)

        $UserLocale = Search-List -Prompt "Please search for a User locale e.g. English (Australia)" -Items $locales.LanguageName
        $languageSelection.Add("UserLocale", $locales[$UserLocale].BCP47tag)

        Clear-Host

        Write-Host "Please confirm the following locale Settings" -ForegroundColor Green
        Write-Host "Input Locale: $($languageSelection.InputLocale)"
        Write-Host "UI Language: $($languageSelection.UILanguage)"
        Write-Host "System Locale: $($languageSelection.SystemLocale)"
        Write-Host "System Locale Fallback: $($languageSelection.SystemLocaleFallback)"
        Write-Host "User Locale: $($languageSelection.UserLocale)"
        $confirm = Read-Host "Is this correct? (y/n) or b to go back"
        if($confirm -eq "y") {
            break
        } elseif ($confirm -eq "q"){
            return $null
        }
    }
}
#endregion

#region Run Script
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
#endregion

#region Cleanup
Remove-Module VentoyAPHelpers
Remove-Module PowerInput
#endregion