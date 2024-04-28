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
$DefaultScopes = "Device.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementServiceConfig.ReadWrite.All", "Domain.Read.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All", "User.Read"
$AppAuthScopes = "Application.ReadWrite.All","Device.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementServiceConfig.ReadWrite.All", "Domain.Read.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All", "User.Read"

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
                New-APProfile -ISO $ISO.Name
            } else {
                break
            }
        } else {
            $addAPProfile = Get-ListSelection -Title "What would you like to do with $($ISO.Name)?" -Items "Assign/Unassign AutoPilot Profile","Create a new AutoPilot Profile" -AllowCancel

            if($null -eq $addAPProfile) {
                break
            } elseif ($addAPProfile -eq 1) {
                New-APProfile -ISO $ISO.Name
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
    param(
        $ISO
    )

    Clear-Host
    $languageSelection = @{}
    $APProfileName = ""
    $diskID = ""
    $key = ""
    $timezone = ""
    $assignment = $null

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
        $locales = Import-Csv "$AutoPilotScriptPath\data\locales.csv"
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
        $kmsKeys = Import-Csv "$AutoPilotScriptPath\data\kmskeys.csv"
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
        $timezones = Import-Csv "$AutoPilotScriptPath\data\timezones.csv"
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

    try {
        $windowsAutoPilotIntune = Import-Module WindowsAutoPilotIntune -PassThru -Force -ErrorAction Ignore
    } catch {
        if($_.Exception.Message -match "Assembly with same name is already loaded") {
            Write-Host "Module WindowsAutoPilotIntune already loaded" -ForegroundColor Yellow
            $windowsAutoPilotIntune = $true
        }
    }

    try {
        $graphAuth = Import-Module microsoft.graph.authentication -PassThru -Force -ErrorAction Ignore
    } catch {
        if($_.Exception.Message -match "Assembly with same name is already loaded") {
            Write-Host "Module microsoft.graph.authentication already loaded" -ForegroundColor Yellow
            $graphAuth = $true
        }
    }


    if (-not $graphAuth -or -not $windowsAutoPilotIntune) {
        Write-Host "Installing Required Modules" -ForegroundColor Green
        $provider = Get-PackageProvider NuGet -ErrorAction Ignore
        if (-not $provider) {
            Write-Host "Installing provider NuGet"
            Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
        }
        if (-not $graphAuth) {
            Write-Host "Installing module microsoft.graph.authentication"
            Install-Module Microsoft.Graph.Authentication -Force
        }
        if (-not $windowsAutoPilotIntune) {
            Write-Host "Installing module WindowsAutoPilotIntune"
            Install-Module WindowsAutoPilotIntune -Force
        }
    }

    Import-Module WindowsAutoPilotIntune -Force



    $authenticated = $false
    $attempts = 1
    while (-not $authenticated) {
        Write-Host "Login to Microsoft Graph"
        try {
            Connect-MgGraph -Scopes $DefaultScopes -NoWelcome -ErrorAction Stop
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

        $AllDevicesOfflineFlag = $false
        if ($assignment -eq "All Devices") {
            $AllDevicesOfflineSelection = Get-ListSelection -Title "What deployment method do you prefer" -Items "Drop AutoPilot JSON File","Collect Hardware Hashes"
            if ($AllDevicesOfflineSelection -eq 0) {
                $AllDevicesOfflineFlag = $true
            }
        }

        $requireLogin = $true
        if(-not $AllDevicesOfflineFlag -and -not $assignment.targetsOfflineJoin) {
            $authMethod = Get-ListSelection -Title "What authentication method do you prefer" -Items "Require Login","Application Secret (Requires Application Administrator Role to setup)"
            if ($authMethod -eq 1) {
                $requireLogin = $false
            }
        }

        Clear-Host
        Write-Host "Please confirm the following AutoPilot Profile and Assignment" -ForegroundColor Green
        Write-Host "Profile: $($APProfile.displayName)"
        if ($assignment -eq "All Devices") {
            Write-Host "Assignment Method: All Devices"
            if($AllDevicesOfflineFlag) {
                Write-Host "Deployment Method: JSON File Drop"
            } else {
                Write-Host "Deployment Method: Hash Capture"
            }
        } else {
            if ($assignment.targetsOfflineJoin) {
                Write-Host "Assignment Method: Offline Join JSON"
                Write-Host "Dynamic Group: $($assignment.displayName)"
                Write-Host "Dynamic Rule: $($assignment.dynamicRule)"
                Write-Host "Deployment Method: JSON File Drop"
            } elseif ($assignment.isDynamic) {
                Write-Host "Assignment Method: Dynamic Group"
                Write-Host "Dynamic Group: $($assignment.displayName)"
                Write-Host "Dynamic Rule: $($assignment.dynamicRule)"
                Write-Host "Deployment Method: Hash Capture"
            } else {
                Write-Host "Assignment Method: Static Group"
                Write-Host "Group: $($assignment.displayName)"
                Write-Host "Deployment Method: Hash Capture and Group Assignment"
            }
        }
        if($requireLogin) {
            Write-Host "Authentication Method: Login"
        } else {
            Write-Host "Authentication Method: Application Secret"
        }
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
    Write-Host "Creating AutoPilot Profile" -ForegroundColor Green

    # APP SETUP
    if(-not $requireLogin) {
        Write-Host "Please login with Application Administrator credentials" -ForegroundColor Green

        $appAdminAuthenticated = $false
        $appAdminAttempts = 1
        while (-not $appAdminAuthenticated) {
            Write-Host "Login to Microsoft Graph"
            try {
                Connect-MgGraph -Scopes $AppAuthScopes -NoWelcome -ErrorAction Stop
                $appAdminAuthenticated = $true
            } catch {
                if($appAdminAttempts -ge 3) {
                    Write-Error "Unable to authenticate to Microsoft Graph with Application Administrator (3 failed attempts - quitting)`n$_"
                    Start-Sleep -Seconds 10
                    continue
                }
                Write-Error "Unable to authenticate to Microsoft Graph with Application Administrator (trying again in 10s)`n$_"
                Start-Sleep -Seconds 10
                $appAdminAttempts++
            }
        }

        $tenant = ""
        try {
            $tenantDetails = Invoke-MGGraphRequest -Uri "$graphApiUri/organization" -Method Get
            $tenant = $tenantDetails.value.id
        } catch {
            Write-Error "Unable to get Tenant Details`n$_"
            Start-Sleep -Seconds 10
            return $null
        }

        $apps = @()
        try {
            $appsResponse = invoke-MGGraphRequest -Uri "$graphApiUri/applications"
            $apps += $appsResponse.value
            $appsNextLink = $response."@odata.nextLink"

            while ($null -ne $appsNextLink){
                $appsResponse = (Invoke-MgGraphRequest -Uri $appsNextLink -Method Get)
                $appsNextLink = $appsResponse."@odata.nextLink"
                $apps += $appsResponse.value
            }
        } catch {
            Write-Error "Unable to get Applications from Microsoft Graph`n$_"
            Start-Sleep -Seconds 10
            return $null
        }

        if($apps.displayName -contains "VentoyAP") {
            Write-Host "Found VentoyAP Application" -ForegroundColor Green
            $app = $apps | Where-Object { $_.displayName -eq "VentoyAP" }
        } else {
            $app = $null
            Write-Host "Unable to Find VentoyAP Application - setting it up" -ForegroundColor Green
            $newApplicationBody = @{ 
                displayName = "VentoyAP"; 
                requiredResourceAccess = @(
                    @{
                        resourceAppId = "00000003-0000-0000-c000-000000000000";
                        resourceAccess = @(
                            @{id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d";type = "Scope"},
                            @{id = "1138cb37-bd11-4084-a2b7-9f71582aeddb";type = "Role"},
                            @{id = "243333ab-4d21-40cb-a475-36241daa0842";type = "Role"},
                            @{id = "5ac13192-7ace-4fcf-b828-1a26f28068ee";type = "Role"},
                            @{id = "62a82d76-70ea-41e2-9197-370581804d09";type = "Role"},
                            @{id = "dbaae8cf-10b5-4b86-a4a1-f871c94c6695";type = "Role"}
                        )
                    }
                )
            }

            $newApplicationBodyJson = $newApplicationBody | ConvertTo-Json -Depth 5

            try {
                $app = Invoke-MGGraphRequest -Uri "$graphApiUri/applications" -Method Post -Body $newApplicationBodyJson
            } catch {
                Write-Error "Unable to create VentoyAP Application`n$_"
                Start-Sleep -Seconds 10
                return $null
            }

            # TODO: Grant Admin Consent (or prompt user to) if not already granted

        }

        #SECRET PERIOD SELECTION
        while ($true) {
            Clear-Host
            $secretName = Read-Host "Enter the name of the Application Secret e.g. Jordans USB - Brisbane"

            $SecretPeriods = @(
                @{Name = "90 Days (3 Months)"; Value = 90},
                @{Name = "180 Days (6 Months)"; Value = 180},
                @{Name = "365 Days (1 Year)"; Value = 365},
                @{Name = "730 Days (2 Years)"; Value = 730}
            )
            $secretPeriodSelection = Get-ListSelection -Title "Select the period for the Application Secret" -Items $SecretPeriods.Name -AllowCancel
            if ($null -eq $secretPeriodSelection) {
                return $null
            } else {
                $secretPeriod = $SecretPeriods[$secretPeriodSelection].Value
                $startDate = Get-Date
                $endDate = $startDate.AddDays($secretPeriod)
            }

            Clear-Host
            Write-Host "Please confirm the following Application Secret settings" -ForegroundColor Green
            Write-Host "Secret Name: $secretName"
            Write-Host "Secret Period: $($SecretPeriods[$secretPeriodSelection].Name)"
            Write-Host "Start Date: $($startDate.ToString("dd-MM-yyyy"))"
            Write-Host "End Date: $($endDate.ToString("dd-MM-yyyy"))"
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

        #SECRET CREATION
        $appSecret = ""
        try {
            $newSecretBody = @{
                displayName = $secretName;
                endDateTime = Get-Date $endDate.ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
                startDateTime = Get-Date $startDate.ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
            }
            $newSecretBodyJson = $newSecretBody | ConvertTo-Json
            $appSecretResponse = Invoke-MGGraphRequest -Uri "$graphApiUri/applications/$($app.id)/addPassword" -Method Post -Body $newSecretBodyJson
            $appSecret = $appSecretResponse.secretText
            Write-Host "Application Secret Created" -ForegroundColor Green
            Write-Host "Name: $($appSecretResponse.displayName)"
            Write-Host "Secret: $($appSecretResponse.secretText)"
        } catch {
            Write-Error "Unable to create VentoyAP Application Secret`n$_"
            Start-Sleep -Seconds 10
            return $null
        }
    }

    Clear-Host
    Write-Host "Setting Up AutoPilot Profile for Ventoy" -ForegroundColor Green
    Start-Sleep -Seconds 2

    # CREATE PROFILE
    $profileObject = @{
        OfflineOnly = $false;
        EnrollmentProfileName = $APProfile.displayName;
        TenantId = $tenant;
        AppId = $app.appId;
        AppSecret = $appSecret;
        LanguageSettings = $languageSelection
        AddToGroup = ""
    }
    if ($AllDevicesOfflineFlag -or $assignment.targetsOfflineJoin) {
        $profileObject.OfflineOnly = $true
    } else {
        $profileObject.AddToGroup = $assignment.displayName
    }

    $profileJson = $profileObject | ConvertTo-Json -Depth 5
    $profileJson | Set-Content -Path "$AutoPilotPath\Profiles\$APProfileName.json" -Encoding Ascii -Force


    Write-Host "Creating Offline Join JSON File" -ForegroundColor Green
    $offlineProfileJSON = $APProfile | ConvertTo-AutopilotConfigurationJSON
    $offlineProfileJSON | Set-Content -Path "$AutoPilotPath\OfflineJoinFiles\$APProfileName.json" -Encoding Ascii -Force

    Write-Host "Creating Phase 1 Unattend File" -ForegroundColor Green
    $contents = Get-Content "$AutoPilotPath\unattendphases\phase1template.xml"
    $script = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"67..90|%{[Char]`$PSItem}|%{if(Test-Path `$(`$_+':\AutoPilot\Scripts\run.ps1')){&`$(`$_+':\AutoPilot\Scripts\run.ps1') -ProfileName '$APProfileName' -Phase '1'}}`"" 
    $newContents = $contents.Replace("{{UILanguage}}", $languageSelection.UILanguage)
    $newContents = $newContents.Replace("{{InputLocale}}", $languageSelection.InputLocale)
    $newContents = $newContents.Replace("{{SystemLocale}}", $languageSelection.SystemLocale)
    $newContents = $newContents.Replace("{{UserLocale}}", $languageSelection.UserLocale)
    $newContents = $newContents.Replace("{{DiskID}}", $diskID)
    $newContents = $newContents.Replace("{{ProductKey}}", $key)
    $newContents = $newContents.Replace("{{TimeZone}}", $timezone)
    $newContents = $newContents.Replace("{{CopyPhase2}}", $script)
    $newContents -join "`r`n" | Out-File -FilePath "$AutoPilotPath\$APProfileName.xml" -NoNewline -Encoding "UTF8" -Force

    Write-Host "AutoPilot Profile Created" -ForegroundColor Green
    Start-Sleep -Seconds 2

    if([string]::IsNullOrEmpty($ISO)) {
        Write-Host "Activating AutoPilot Profile " -ForegroundColor Green
        Add-AutoInstall -VentoyJson $VentoyJson -ISO $ISO -UnattendFile "$APProfileName.xml"
    }

    Start-Sleep -Seconds 5
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