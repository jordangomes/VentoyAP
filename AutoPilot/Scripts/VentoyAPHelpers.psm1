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

function Get-AutoPilotProfileAssignmentDetails {
    param (
        $profileAssignments,
        $profileId
    )
    $assignmentDetails = @()
    foreach($assignment in $profileAssignments) {
        if($assignment.target."@odata.type" -eq "#microsoft.graph.groupAssignmentTarget") {
            Write-Host "Getting group details for: $($assignment.target.groupId)"
            $response = Invoke-MGGraphRequest -Uri "https://graph.microsoft.com/beta/groups/$($assignment.target.groupId)" -Method Get
            $groupDetails = "" | Select-Object id, displayName, isDynamic, targetsOfflineJoin, dynamicRule
            $groupDetails.id = $response.id
            $groupDetails.displayName = $response.displayName
            if($response.groupTypes -contains "DynamicMembership" -and $response.membershipRuleProcessingState -eq "On") {
                $groupDetails.isDynamic = $true
                $groupDetails.dynamicRule = $response.membershipRule
                if($response.membershipRule -like "*OfflineAutopilotProfile-$profileId*") {
                    $groupDetails.targetsOfflineJoin = $true
                } else {
                    $groupDetails.targetsOfflineJoin = $false
                }
            } else {
                $groupDetails.isDynamic = $false
                $groupDetails.dynamicRule = ""
                $groupDetails.targetsOfflineJoin = $false
            }
            $assignmentDetails += $groupDetails
        } elseif($assignment.target."@odata.type" -eq "#microsoft.graph.allDevicesAssignmentTarget") {
            $assignmentDetails += "All Devices"
        }
    }
    return $assignmentDetails
}