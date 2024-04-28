#CONFIG
param (
    [Parameter(Mandatory=$true)] $ProfileName
)

# Setup Logging
$Serial = $(Get-WmiObject win32_bios).SerialNumber
$Date = Get-Date -Format "yyyyMMdd"
$LogFile = "$PSScriptRoot\..\Logs\$Serial-$Date.log"
Start-Transcript -Path $LogFile -Append

# Load Config
$Config = Get-Content "$PSScriptRoot\..\Profiles\$ProfileName.json" | ConvertFrom-Json -Depth 5

$exit = $FALSE
$addedToAP = $FALSE
while (-not $exit) {

    if ($OfflineOnly -eq $true) {
        Write-Host "Offline Only Mode - Skipping Hash Collection"
        $exit = $true
        break
    }

    # Wait for Internet Connection
    $internet = $false
    while ($internet -eq $false) {
        try {
            Write-Host "Checking Internet Connection"
            $internet = Test-NetConnection -ComputerName "www.microsoft.com" -Port 443 -InformationLevel Quiet
            if ($internet -ne $true) {
                Write-Host "No Internet Connection"
                Start-Sleep -Seconds 5
            }
        } catch {
            Write-Host "No Internet Connection"
            Start-Sleep -Seconds 5
        }
    }

    # Install and Import Required Modules
    try { 
        Write-Host "Uploading AutoPilot Hash to $ProfileName"
        Set-ExecutionPolicy bypass -Scope Process -Force

        # Install Modules
        Find-PackageProvider -Name NuGet -Force -IncludeDependencies
        Install-Module Microsoft.Graph.Authentication -Force
        Install-Module WindowsAutopilotIntune -Force
        Install-Module Microsoft.Graph.Groups -Force
        Install-Module Microsoft.Graph.Identity.DirectoryManagement -Force

        # Import Modules
        Import-Module Microsoft.Graph.Authentication -Scope Global
        Import-Module WindowsAutopilotIntune -Scope Global
        Import-Module Microsoft.Graph.Groups -Scope Global
        Import-Module Microsoft.Graph.Identity.DirectoryManagement -Scope Global
        Import-Module "$PSScriptRoot\AutoPilotHelpers.psm1"
    } catch {
        Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error Installing Required Modules `n $($_.Exception.ToString())"
        $prompt = Read-Host -Prompt "Press enter to try again or type skip to skip hash collection"
        if ($prompt -eq "skip") {
            Write-Host "Skipping Hash Collection"
            $exit = $true
            break;
        }
        continue;
    }

    # Collect Hash
    try {
        $session = New-CimSession
        $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
        if ($devDetail) {
            $hash = $devDetail.DeviceHardwareData
        } else { 
            throw "No Hash Found" 
        }
    } catch {
        Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error harvesting hash `n $($_.Exception.ToString())"
        $prompt = Read-Host -Prompt "Press enter to try again or type skip to skip hash collection"
        if ($prompt -eq "skip") {
            Write-Host "Skipping Hash Collection"
            $exit = $true
            break;
        }
        continue;
    }

    try {
        if([string]::IsNullOrEmpty($Config.AppSecret)) {
            Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Device.ReadWrite.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All"
        } else {
            Connect-MSGraphApp -Tenant $Config.TenantId -AppId $Config.AppId -AppSecret $Config.AppSecret
        }
        $device = Get-AutopilotDevice -serial $serial
        if ($device) {
            Write-Host "Device already exists in AutoPilot will check if it is in $($Config.EnrollmentProfileName)"
            $addedToAP = $true
            $synced = $device
        }
    } catch {
        Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error uploading hash `n $($_.Exception.ToString())"
        $prompt = Read-Host -Prompt "Press enter to try again or type skip to skip hash collection"
        if ($prompt -eq "skip") {
            Write-Host "Skipping Hash Collection"
            $exit = $true
        }
    }

    # Upload Hash
    try {
        if(-not $addedToAP) {
            $import = Add-AutopilotImportedDevice -SerialNumber $serial -HardwareIdentifier $hash -ErrorAction Stop
            $imported = Wait-ForDeviceImport -deviceImport $import
            $synced = Wait-ForDeviceSync -importedDevice $imported
            $addedToAP = $true
        }
        
        Add-ToAADGroup -AutoPilotDevice $synced -group $AddToGroup
        Wait-ForProfileAssignment -AutoPilotDevice $synced -Profile $Config.EnrollmentProfileName
        Write-Host "AutoPilot Hash uploaded to $ProfileName"
        $exit = $true
    } catch {
        Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error uploading hash `n $($_.Exception.ToString())"
        $prompt = Read-Host -Prompt "Press enter to try again or type skip to skip hash collection"
        if ($prompt -eq "skip") {
            Write-Host "Skipping Hash Collection"
            $exit = $true
        }
    }

}

# Copy AutoPilot Configuration File to System to force it to join AutoPilot
try {
    Write-Host "Copying AutoPilot Offline Join File $ProfileName to System"
    Copy-Item -Path "$PSScriptRoot\..\OfflineJoinFiles\$($ProfileName).json" -Destination "C:\Windows\Provisioning\Autopilot\AutoPilotConfigurationFile.json" -Force
} catch {
    Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error copying file `n $($_.Exception.ToString())"
    Read-Host -Prompt "Press any key to continue"
}

try {
    Write-Host "Copying Phase 3 Unattend file to System"
    $contents = Get-Content "$PSScriptRoot\..\unattendphases\phase3.xml"
    $newContents = $contents.Replace("{{UILanguage}}", $Config.LanguageSettings.UILanguage)
    $newContents = $newContents.Replace("{{InputLocale}}", $Config.LanguageSettings.InputLocale)
    $newContents = $newContents.Replace("{{SystemLocale}}", $Config.LanguageSettings.SystemLocale)
    $newContents = $newContents.Replace("{{UserLocale}}", $Config.LanguageSettings.UserLocale)
    $newContents -join "`r`n" | Out-File -FilePath "C:\Windows\Panther\Unattend\Unattend.xml" -NoNewline -Encoding "UTF8" -Force
} catch {
    Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error copying file `n $($_.Exception.ToString())"
    Read-Host -Prompt "Press any key to continue"
}

if($Config.NextScript) {
    Write-Host "Running Next Script - $($Config.NextScript)"
    &"$PSScriptRoot\$($Config.NextScript)"
}

Stop-Transcript -ErrorAction SilentlyContinue