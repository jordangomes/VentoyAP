function Wait-ForDeviceImport {
    param (
        [Parameter(Mandatory=$true)] $deviceImport
    )

    $imported = $FALSE
    $importStart = Get-Date
    while ($imported -ne $TRUE)
    {
        $device = Get-AutopilotImportedDevice -id $deviceImport.id
        if ($device.state.deviceImportStatus -ne "unknown") {
            $imported = $TRUE
        } else {
            Write-Host "Waiting for device to be imported"
            Start-Sleep 30
        }
    }

    if ($device.state.deviceImportStatus -eq "complete") {
        $importDuration = (Get-Date) - $importStart
        $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
        Write-Host "Device imported successfully. Elapsed time to complete import: $importSeconds seconds"
        return $device
    } else {
        throw "Device import failed - status $($device.state.deviceImportStatus)"
    }
}

function Wait-ForDeviceSync {
    param (
        [Parameter(Mandatory=$true)] $importedDevice
    )
    $syncStart = Get-Date
    while ($TRUE)
    {
        $device = Get-AutopilotDevice -id $importedDevice.state.deviceRegistrationId
        if (-not $device) {
            Write-Host "Waiting for device to be synced"
            Start-Sleep 30
        } else {
            $syncDuration = (Get-Date) - $syncStart
            $syncSeconds = [Math]::Ceiling($syncDuration.TotalSeconds)
            Write-Host "Device synced.  Elapsed time to complete sync: $syncSeconds seconds"
            return $device
        }
    }
}

function Add-ToAADGroup {
    param (
        [Parameter(Mandatory=$true)] $AutoPilotDevice,
        [Parameter(Mandatory=$true)] $group
    )
    $aadGroup = Get-MgGroup -Filter "DisplayName eq '$group'"
    if ($aadGroup)
    {
        $aadDevice = Get-MgDevice -Search "deviceId:$($AutoPilotDevice.azureActiveDirectoryDeviceId)" -ConsistencyLevel eventual
        if ($aadDevice) {
            Write-Host "Getting Device Groups"
            $groups =  Get-MgDeviceMemberOf -DeviceId $aadDevice.Id
            $alreadyAdded = $FALSE
            foreach ($group in $groups) {
                if($group.id -ne $aadGroup.Id) {
                    if ($group.additionalProperties.membershipRuleProcessingState -eq "On"){
                        Write-Host "Not removing device from group $($group.additionalProperties.displayName) as it is dynamically assigned"
                    } else {
                        Write-Host "Removing device from additional group $($group.additionalProperties.displayName)"
                        Remove-MgGroupMemberByRef -GroupId $($group.id) -DirectoryObjectId $($aadDevice.Id) -ErrorAction Continue
                    }
                } else {
                    $alreadyAdded = $TRUE
                }
            }
            if ($alreadyAdded) {
                Write-Host "Device already in group $($group.additionalProperties.displayName)"
            } else {
                Write-Host "Adding device $($AutoPilotDevice.serialNumber) to group $($aadGroup.DisplayName)"
                New-MgGroupMember -GroupId $($aadGroup.Id) -DirectoryObjectId $($aadDevice.Id) -ErrorAction Continue
                Write-Host "Added device to group '$($aadGroup.DisplayName)' $($aadGroup.Id)"
            }

        } else {
            throw "Unable to find Azure AD device with ID $($AutoPilotDevice.azureActiveDirectoryDeviceId)"
        }
    } else {
        throw "Unable to find group $group"
    }
}

function Wait-ForProfileAssignment {
    param (
        [Parameter(Mandatory=$true)] $AutoPilotDevice,
        [Parameter(Mandatory=$true)] $Profile
    )
    $assignStart = Get-Date
    while ($TRUE)
    {
        $device = Get-AutopilotDevice -id $AutoPilotDevice.id -Expand
        if ($device.deploymentProfileAssignmentStatus.StartsWith("assigned")) {
            if($device.deploymentProfile.displayName -ne $Profile) {
                Write-Host "Waiting for device to be assigned to $Profile currently assigned to $($device.deploymentProfile.displayName)"
                Start-Sleep 30
            } else {
                $assignDuration = (Get-Date) - $assignStart
                $assignSeconds = [Math]::Ceiling($assignDuration.TotalSeconds)
                Write-Host "Profiles assigned to device.  Elapsed time to complete assignment: $assignSeconds seconds"
                return;
            }
        } else {
            Write-Host "Waiting for AutoPilot Profile to be assigned"
            Start-Sleep 30
        }
    }
}