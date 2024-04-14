function Select-ISO {
    param (
        [Parameter(Mandatory=$TRUE)]$AutoInstallISOs,
        [Parameter(Mandatory=$TRUE)]$ISOFiles,
        [Parameter(Mandatory=$TRUE)]$BasePath
    )
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
        $input = Read-Host "Select the ISO to configure auto-install for (1-$($ISOFiles.Count)) or enter c to cancel"
        try {
            $numInput = [int]$input
        } catch {
            $numInput = 0
        }
        if($numInput -ge 1 -and [int]$input -le $ISOFiles.Count) {
            return $ISOFiles[$numInput - 1].Name
        } elseif ($input -eq "c") {
            Exit
        } else {
            Write-Host "Invalid selection, please try again" -ForegroundColor Red
        }
    }
}