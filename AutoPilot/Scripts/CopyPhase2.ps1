param ($name)

# Setup Logging
$Serial = $(Get-WmiObject win32_bios).SerialNumber
$Date = Get-Date -Format "yyyyMMdd"
$LogFile = "$PSScriptRoot\..\Logs\Unattend-$Serial-$Date.log"
Start-Transcript -Path $LogFile -Append

# Create Folder if not exists
New-Item -ItemType Directory -Path "C:\Windows\Panther\Unattend" -Force -ErrorAction Continue

# Copy Unattend File
try {
    Write-Host "Copying Unattend file to System"
    $contents = Get-Content "$PSScriptRoot\..\unattendphases\phase2.xml"
    $script = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"67..90|%{[Char]`$PSItem}|%{if(Test-Path `$(`$_+':\AutoPilot\Scripts\run.ps1')){&`$(`$_+':\AutoPilot\run.ps1') -ProfileName '$name' -Phase '2'}}`"" 
    $newContents = $contents.Replace("{{CollectAPHash}}", $script)
    $newContents -join "`r`n" | Out-File -FilePath "C:\Windows\Panther\Unattend\Unattend.xml" -NoNewline -Encoding "UTF8" -Force
} catch {
    Write-Error "[ERROR] $(Get-Date -Format "dd-MM-yy HH:mm:ss") Error copying file `n $($_.Exception.ToString())"
    Read-Host -Prompt "Press any key to continue"
}
Stop-Transcript -ErrorAction SilentlyContinue