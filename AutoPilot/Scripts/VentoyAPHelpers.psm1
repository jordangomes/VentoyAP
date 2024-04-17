function Get-ISOs {
    param (
        [Parameter(Mandatory=$TRUE)]$BasePath
    )
    $ISOFiles = Get-ChildItem -Path $ISOPath -Filter *.iso
    if ($ISOFiles.Count -eq 0) {
        Write-Host "No ISO files found in the current directory. Exiting.." -ForegroundColor Yellow
        Exit
    } else {
        return $ISOFiles
    }
}

function Get-AllAutoInstalls {
    param (
        [Parameter(Mandatory=$TRUE)]$VentoyJson
    )
    if (Test-Path $VentoyJson) {
        $VentoyJsonContent = Get-Content $VentoyJson | ConvertFrom-Json -ErrorAction Stop
        $AutoInstallISOs = $VentoyJsonContent.auto_install
    } else {
        $AutoInstallISOs = @()
    }
    return $AutoInstallISOs
}

function Get-AutoInstalls {
    param (
        [Parameter(Mandatory=$TRUE)]$VentoyJson,
        [Parameter(Mandatory=$TRUE)]$ISO
    )
    if (Test-Path $VentoyJson) {
        $VentoyJsonContent = Get-Content $VentoyJson | ConvertFrom-Json -ErrorAction Stop
        $AutoInstallISOs = $VentoyJsonContent.auto_install
        $AutoInstalls = $AutoInstallISOs | Where-Object { $_.image -eq "/$ISO" }
        return $AutoInstalls
    } else {
        return @()
    }
}

function Add-AutoInstall {
    param(
        [Parameter(Mandatory=$TRUE)]$VentoyJson,
        [Parameter(Mandatory=$TRUE)]$ISO,
        [Parameter(Mandatory=$TRUE)]$UnattendFile
    )

    $NewAutoInstall = @{
        image = "/$ISO"
        template = @("/AutoPilot/$($UnattendFile)")
    }

    if (Test-Path $VentoyJson) {
        $VentoyJsonContent = Get-Content $VentoyJson | ConvertFrom-Json -ErrorAction Stop
        if($null -eq $VentoyJsonContent.auto_install) {
            $VentoyJsonContent | Add-Member -MemberType NoteProperty -Name auto_install -Value @($NewAutoInstall)
        } else {
            $isoExists = $false
            foreach ($AutoInstall in $VentoyJsonContent.auto_install) {
                if ($AutoInstall.image -eq "/$ISO") {
                    $isoExists = $true
                    $AutoInstall.template += "/AutoPilot/$($UnattendFile)"
                }
            }
            if(-not $isoExists) {
                $VentoyJsonContent.auto_install += $NewAutoInstall
            }
        }

        Set-Content -Path $VentoyJson -Value ($VentoyJsonContent | ConvertTo-Json -Depth 10) -Force
        Write-Host "Auto-Install added to $ISO" -ForegroundColor Green
        return
    } else {
        $VentoyJsonContent = @{
            auto_install = @(
                $NewAutoInstall
            )
        }
        Set-Content -Path $VentoyJson -Value ($VentoyJsonContent | ConvertTo-Json -Depth 10) -Force
        Write-Host "Auto-Install added to $ISO" -ForegroundColor Green
    }
}

function Remove-AutoInstall {
    param(
        [Parameter(Mandatory=$TRUE)]$VentoyJson,
        [Parameter(Mandatory=$TRUE)]$ISO,
        [Parameter(Mandatory=$TRUE)]$UnattendFile
    )
    if (Test-Path $VentoyJson) {
        $VentoyJsonContent = Get-Content $VentoyJson | ConvertFrom-Json -ErrorAction Stop
        foreach ($AutoInstall in $VentoyJsonContent.auto_install) {
            if ($AutoInstall.image -eq "/$ISO") {
                $templates = $AutoInstall.template | Where-Object { $_ -ne "/AutoPilot/$($UnattendFile)" }
                if($templates.Count -eq 0) {
                    $ISOs = $VentoyJsonContent.auto_install | Where-Object { $_.image -ne "/$ISO" }
                    if($ISOs.Count -eq 0) {
                        $VentoyJsonContent.PSObject.Properties.Remove("auto_install")
                    } else {
                        $VentoyJsonContent.auto_install = $ISOs
                    }
                }
                Set-Content -Path $VentoyJson -Value ($VentoyJsonContent | ConvertTo-Json -Depth 10) -Force
                Write-Host "Auto-Install removed from $ISO" -ForegroundColor Green
                return
            }
        }
    } else {
        Write-Host "No auto-installs found for $ISO" -ForegroundColor Yellow 
    }
}

function Select-Locale {
    param (
        [Parameter(Mandatory=$TRUE)]$File,
        [Parameter(Mandatory=$TRUE)]$Prompt,
        [parameter()][switch]$System
    )
    if($system) {
        $locales = Import-Csv $File | Where-Object { $_.System -eq "Yes" }
    } else {
        $locales = Import-Csv $File
    }

    $columns = ($locales | get-Member -MemberType NoteProperty).Name
    $results = @()
    foreach ($column in $columns) {
        if($column -ne "System") {
            $results += $locales | Where-Object -Property $column -Like -Value "*$Prompt*"
        }
    }

    $i = 0
    foreach ($result in $results) {
        $i++
        Write-Host "$i - $($result.LanguageName) ($($result[$numInput - 1].BCP47tag))"
    }
    $localeInput = Read-Host "Select a locale (1-$($results.Count))"
    try {
        $numInput = [int]$localeInput
    } catch {
        $numInput = 0
    }
    if($numInput -ge 1 -and $numInput -le $results.Count) {
        return $results[$numInput - 1]
    } else {
        Write-Host "Invalid selection, please try again " -ForegroundColor Red
        return $null
    }
}

function New-APProfile {
    param (
        [Parameter(Mandatory=$TRUE)]$AutoPilotPath
    )
    
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
        Write-Host "`nPlease search for a input language"
        while ($true) {
            $InputLocalePrompt = Read-Host "Input Locale"
            $InputLocale = Select-Locale -File "$AutoPilotPath\Scripts\locales.csv" -Prompt $InputLocalePrompt
            if($null -ne $InputLocale) {
                Write-Host "Selected Input Locale: $($InputLocale.Code)" -ForegroundColor Green
                $languageSelection.Add("InputLocale", $InputLocale.Code)
                break
            }
            
    
        }
    
        Write-Host "`nPlease search for a UI Language"
        while ($true) {
            $UILanguagePrompt = Read-Host "UI Language"
            $UILanguage = Select-Locale -File "$AutoPilotPath\Scripts\locales.csv" -Prompt $UILanguagePrompt -System
            if($null -ne $UILanguage) {
                Write-Host "Selected UI Language: $($UILanguage.BCP47tag)" -ForegroundColor Green
                $languageSelection.Add("UILanguage", $UILanguage.BCP47tag)
                break
            }
        }
    
        Write-Host "`nPlease search for a System Locale"
        while ($true) {
            $SystemLocalePrompt = Read-Host "System Locale"
            $SystemLocale = Select-Locale -File "$AutoPilotPath\Scripts\locales.csv" -Prompt $SystemLocalePrompt -System
            if($null -ne $SystemLocale) {
                Write-Host "Selected System Locale: $($SystemLocale.BCP47tag)" -ForegroundColor Green
                $languageSelection.Add("SystemLocale", $SystemLocale.BCP47tag)
                break
            }
        }
    
        Write-Host "`nPlease search for a System Locale Fallback"
        while ($true) {
            $SystemLocaleFallbackPrompt = Read-Host "System Locale Fallback"
            $SystemLocaleFallback = Select-Locale -File "$AutoPilotPath\Scripts\locales.csv" -Prompt $SystemLocaleFallbackPrompt -System
            if($null -ne $SystemLocaleFallback) {
                Write-Host "Selected System Locale Fallback: $($SystemLocaleFallback.BCP47tag)" -ForegroundColor Green
                $languageSelection.Add("SystemLocaleFallback", $SystemLocaleFallback.BCP47tag)
                break
            }
        }
    
    
        Write-Host "`nPlease search for a User Locale"
        while ($true) {
            $UserLocalePrompt = Read-Host "User Locale"
            $UserLocale = Select-Locale -File "$AutoPilotPath\Scripts\locales.csv" -Prompt $UserLocalePrompt
            if($null -ne $UserLocale) {
                Write-Host "Selected User Locale: $($UserLocale.BCP47tag)" -ForegroundColor Green
                $languageSelection.Add("UserLocale", $UserLocale.BCP47tag)
                break
            }
        }
        Write-Host "`nPlease confirm the following locale Settings" -ForegroundColor Green
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

function Select-ISO {
    param (
        [Parameter(Mandatory=$TRUE)]$BasePath,
        [Parameter(Mandatory=$TRUE)]$VentoyJson
    )

    $AutoInstallISOs = Get-AllAutoInstalls -VentoyJson $VentoyJson
    $ISOFiles = Get-ISOs -BasePath $BasePath

    $i = 0
    foreach ($ISOFile in $ISOFiles) {
        $i++
        $AutoInstall = $AutoInstallISOs | Where-Object { $_.image -eq "/$($ISOFile.Name)" }
        if ($AutoInstall.template) {
            Write-Host "$i - $($ISOFile.Name)"
            foreach($template in $AutoInstall.template) {
                $TemplatePath = Join-Path -Path $BasePath -ChildPath $template
                if(Test-Path $TemplatePath) {
                    Write-Host "    $template" -ForegroundColor Green
                } else {
                    Write-Host "    $template - File does not exist" -ForegroundColor Red
                }
            } 
        } else {
            Write-Host "$i - $($ISOFile.Name) - No Auto-Installs Configured" -ForegroundColor Yellow
        }
    }
    while ($true){
        $ISOinput = Read-Host "`nSelect the ISO to configure auto-installs for (1-$($ISOFiles.Count)) or enter q to quit"
        Write-Host ""
        try {
            $numInput = [int]$ISOinput
        } catch {
            $numInput = 0
        }
        if($numInput -ge 1 -and [int]$ISOinput -le $ISOFiles.Count) {
            return $ISOFiles[$numInput - 1].Name
        } elseif ($ISOinput -eq "q") {
            Exit
        } else {
            Write-Host "Invalid selection, please try again" -ForegroundColor Red
        }
    }
}