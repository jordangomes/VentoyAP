param (
    [Parameter(Mandatory=$true)] $ProfileName,
    [Parameter(Mandatory=$true)] $Phase
)

try {
    if($Phase -eq "1") {
        Write-Host "Running Phase 1"
        &"$PSScriptRoot\CopyPhase2.ps1" -name $ProfileName
    } elseif($Phase -eq "2") {
        Write-Host "Running Phase 2"
        if(Test-Path "$PSScriptRoot\..\Profiles\$ProfileName.json") {
            &"$PSScriptRoot\AutoPilot.ps1" -ProfileName $ProfileName
        } else {
            Write-Host "Profile Not Found - $PSScriptRoot\..\Profiles\$ProfileName.json"
        }
    } else {
        Write-Host "Invalid Phase"
        Read-Host "Press Enter to Exit"
    }
} catch {
    Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error uploading hash `n $($_.Exception.ToString())"
    Read-Host -Prompt "Press enter to continue"
}
