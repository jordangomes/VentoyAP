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
            $addAPProfile = Get-YesNo -Prompt "No AutoPilot profiles found, would you like to create one (y/n)?"

            if($addAPProfile) {
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
    $languageSelection = @{}
    $APProfileName = ""
    $diskID = ""
    $key = ""
    $timezone = ""

    # PROFILE NAME
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

    Clear-Host
    Write-Host "Now Lets Setup your Windows install options..." -ForegroundColor Green
    Start-Sleep 2
    Clear-Host

    # LANGUAGE SELECTION
    while ($true) {
        $languageSelection = @{}
        $locales = Import-Csv "$AutoPilotPath\Scripts\data\locales.csv"
        $systemLocales = $locales | Where-Object { $_.System -eq "Yes" }

        $InputLocale = Search-List -Prompt "Please search for a input language e.g. English (Australia)" -Items $locales.LanguageName
        $languageSelection.Add("InputLocale", $locales[$InputLocale].Code)

        $UILanguage = Search-List -Prompt "Please search for a UI Language e.g. English" -Items $systemLocales.LanguageName
        $languageSelection.Add("UILanguage", $systemLocales[$UILanguage].BCP47tag)
    
        $SystemLocale = Search-List -Prompt "Please search for a System Locale e.g. English" -Items $systemLocales.LanguageName
        $languageSelection.Add("SystemLocale", $systemLocales[$SystemLocale].BCP47tag)

        $UserLocale = Search-List -Prompt "Please search for a User locale e.g. English (Australia)" -Items $locales.LanguageName
        $languageSelection.Add("UserLocale", $locales[$UserLocale].BCP47tag)

        Clear-Host

        Write-Host "Please confirm the following locale Settings" -ForegroundColor Green
        Write-Host "Input Locale: $($languageSelection.InputLocale)"
        Write-Host "UI Language: $($languageSelection.UILanguage)"
        Write-Host "System Locale: $($languageSelection.SystemLocale)"
        Write-Host "User Locale: $($languageSelection.UserLocale)"
        Write-Host ""
        $confirm = Get-YesNo -Inline -AllowCancel
        if($confirm -eq $true) {
            break
        } elseif ($confirm -eq $false){
            continue
        } else {
            return $null
        }
    }

    # DISK SELECTION
    while ($true) {
        $InstallDiskOptions = @(
            "First Non Ventoy Disk"
            "First Non USB Disk"
            "Largest Disk"
            "Disk closest to a certain size"
            "Fixed Disk ID"
        )
        $diskSelection = Get-ListSelection -Title "Select the disk to install Windows on" -Items $InstallDiskOptions -AllowCancel

        $diskID = ""
        if($diskSelection -eq 0) {
            $diskID = "`$`$VT_WINDOWS_DISK_1ST_NONVTOY`$`$"
        } elseif ($diskSelection -eq 1) {
            $diskID = "`$`$VT_WINDOWS_DISK_1ST_NONUSB`$`$"
        } elseif ($diskSelection -eq 2) {
            $diskID = "`$`$VT_WINDOWS_DISK_MAX_SIZE`$`$"
        } elseif ($diskSelection -eq 3) {
            Clear-Host
            while ($true) {
                $diskSize = Read-Host "Enter the size of the disk in GB"
                if($diskSize -match "^\d+$") {
                    $diskID = "`$`$VT_WINDOWS_DISK_CLOSEST_$diskSize`$`$"
                    break
                } else {
                    Write-Host "Please enter a valid number" -ForegroundColor Red
                }
            }
        } elseif ($diskSelection -eq 4) {
            Clear-Host
            while ($true) {
                $possibleDiskID = Read-Host "Enter the Disk ID"
                if ($possibleDiskID -match "^\d+$") {
                    $diskID = "$possibleDiskID"
                    break
                } else {
                    Write-Host "Please enter a valid number" -ForegroundColor Red
                }
            }
        } else {
            return $null
        }

        Clear-Host

        Write-Host "Please confirm the following disk settings" -ForegroundColor Green
        Write-Host "Selection: $($InstallDiskOptions[$diskSelection])"
        Write-Host "DiskID: $($diskID)"
        Write-Host ""
        $confirm = Get-YesNo -Inline -AllowCancel
        if($confirm -eq $true) {
            break
        } elseif ($confirm -eq $false){
            continue
        } else {
            return $null
        }
    }

    # KEY SELECTION
    while ($true) {
        $kmsKeys = Import-Csv "$AutoPilotPath\Scripts\data\kmskeys.csv"
        $options = @("Use my own key")
        foreach($kmsKey in $kmsKeys) {
            $options += "$($kmsKey.Product) (KMS Key)" 
        }
        $keyOption = Get-ListSelection -Title "What activation key would you like to use" -Items $options -AllowCancel
        if($keyOption -eq 0) {
            $key = Read-Host "Enter the KMS key"
        } elseif ($keyOption -gt 0 -and $keyOption -le $kmsKeys.Count) {
            $key = $kmsKeys[$keyOption - 1].Key
        } else {
            return $null
        }

        Clear-Host

        Write-Host "Please confirm the windows key you would like to use" -ForegroundColor Green
        Write-Host "key: $key"
        Write-Host ""
        $confirm = Get-YesNo -Inline -AllowCancel
        if($confirm -eq $true) {
            break
        } elseif ($confirm -eq $false){
            continue
        } else {
            return $null
        }
    }

    # TIMEZONE SELECTION
    while ($true) {
        $timezones = Import-Csv "$AutoPilotPath\Scripts\data\timezones.csv"
        $timezoneOption = Search-List -Prompt "Search for a default timezone (esc to quit)" -Items $timezones.Name -AllowCancel
        
        if ($timezoneOption -gt 0 -and $timezoneOption -le $timezones.Count - 1) {
            $timezone = $timezones[$timezoneOption].Timezone
        } else {
            return $null
        }

        Clear-Host

        Write-Host "Please confirm the Timezone you would like to use" -ForegroundColor Green
        Write-Host "Timezone Name: $($timezones[$timezoneOption].Name)"
        Write-Host "Timezone: $timezone"
        Write-Host ""
        $confirm = Get-YesNo -Inline -AllowCancel
        if($confirm -eq $true) {
            break
        } elseif ($confirm -eq $false){
            continue
        } else {
            return $null
        }
    }

    Clear-Host
    Write-Host "Now Lets Setup your AutoPilot Settings..." -ForegroundColor Green
    Start-Sleep 2
    Clear-Host

    
    $module = Import-Module microsoft.graph.authentication -PassThru -ErrorAction Ignore
    if (-not $module) {
        Write-Host "Installing Required Modules" -ForegroundColor Green
        $provider = Get-PackageProvider NuGet -ErrorAction Ignore
        if (-not $provider) {
            Write-Host "Installing provider NuGet"
            Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
        }
        Write-Host "Installing module microsoft.graph.authentication"
        Install-Module Microsoft.Graph.Authentication -Force
    }
    Import-Module Microsoft.Graph.Authentication

    $authenticated = $false
    $attempts = 1
    while (-not $authenticated) {
        Write-Host "Login to Microsoft Graph"
        try {
            Connect-MgGraph -NoWelcome -ErrorAction Stop
            $authenticated = $true
        } catch {
            if($attempts -ge 3) {
                Write-Error "Unable to authenticate to Microsoft Graph (3 failed attempts - quitting)`n$_"
                Start-Sleep -Seconds 10
                return $null
            }
            Write-Error "Unable to authenticate to Microsoft Graph (trying again in 10s)`n$_"
            Start-Sleep -Seconds 10
            $attempts++
        }
    }

    $graphApiUri = "https://graph.microsoft.com/beta"
    # PROFILE SELECTION
    while ($true) {
        Clear-Host
        Write-Host "Getting AutoPilot Profiles..."
        $profiles = @()
        try {
            $resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
            $response = Invoke-MGGraphRequest -Uri "$graphApiUri/$resource" -Method Get
            $profiles = $response.value
        } catch {
            Write-Error "Unable to get AutoPilot Profiles from Microsoft Graph`n$_"
            Start-Sleep -Seconds 10
            return $null
        }

        $profileSeleciton = Get-ListSelection -Title "Select the AutoPilot Profile to use" -Items $profiles.displayName -AllowCancel
        if($null -eq $profileSeleciton) {
            return $null
        } else {
            $APProfile = $profiles[$profileSeleciton]
        }
        
        Clear-Host
        Write-Host "Getting AutoPilot Profile Assignments..."
        $profileAssignments = @()
        try {
            $resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
            $response = Invoke-MGGraphRequest -Uri "$graphApiUri/$resource/$($APProfile.id)?`$expand=assignments" -Method Get
            $profileAssignments = $response.assignments
        } catch {
            Write-Error "Unable to get AutoPilot Profile ($($APProfile.displayName) - $($APProfile.id)) from Microsoft Graph`n$_"
            Start-Sleep -Seconds 10
            return $null
        }
        
        Write-Host "Getting AutoPilot Profile Assignment Details..."
        $assignmentDetails = Get-AutoPilotProfileAssignmentDetails -profileAssignments $profileAssignments -profileId $APProfile.id

        $methods = @()
        if($assignmentDetails -eq @()) {
            Write-Error "Unable to find any assignments for $($APProfile.displayName) (quitting)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            return $null
        } else {
            foreach($assignment in $assignmentDetails) {
                if($assignment -eq "All Devices") {
                    $methods += "All Devices (Recommended)"
                } else {
                    if ($assignment.targetsOfflineJoin) {
                        $methods += "$($assignment.displayName) (Offline Join JSON)"
                    } elseif ($assignment.isDynamic) {
                        $methods += "$($assignment.displayName) (Dynamic Group)"
                    } else {
                        $methods += "$($assignment.displayName) (Static Group)"
                    }
                }
            }
        }
    
        $assignmentMethod = Get-ListSelection -Title "Select the AutoPilot Profile Assignment Method" -Items $methods -AllowCancel
        if ($null -eq $assignmentMethod) {
            return $null
        } else {
            $assignment = $assignmentDetails[$assignmentMethod]
        }

        Clear-Host
        Write-Host "Please confirm the following AutoPilot Profile and Assignment" -ForegroundColor Green
        Write-Host "Profile: $($APProfile.displayName)"
        if ($assignment -eq "All Devices") {
            Write-Host "Assignment Method: All Devices"
        } else {
            if ($assignment.targetsOfflineJoin) {
                Write-Host "Assignment Method: Offline Join JSON"
                Write-Host "Dynamic Group: $($assignment.displayName)"
                Write-Host "Dynamic Rule: $($assignment.dynamicRule)"
            } elseif ($assignment.isDynamic) {
                Write-Host "Assignment Method: Dynamic Group"
                Write-Host "Dynamic Group: $($assignment.displayName)"
                Write-Host "Dynamic Rule: $($assignment.dynamicRule)"
            } else {
                Write-Host "Assignment Method: Static Group"
                Write-Host "Group: $($assignment.displayName)"
            }
        }
        Write-Host ""
        $confirm = Get-YesNo -Inline -AllowCancel
    }

    Start-Sleep -Seconds 10

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