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

function Get-AutoInstalls {
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

function Select-ISO {
    param (
        [Parameter(Mandatory=$TRUE)]$BasePath,
        [Parameter(Mandatory=$TRUE)]$VentoyJson
    )

    $AutoInstallISOs = Get-AutoInstalls -VentoyJson $VentoyJson
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
        $ISOinput = Read-Host "Select the ISO to configure auto-installs for (1-$($ISOFiles.Count)) or enter c to cancel"
        try {
            $numInput = [int]$ISOinput
        } catch {
            $numInput = 0
        }
        if($numInput -ge 1 -and [int]$ISOinput -le $ISOFiles.Count) {
            return $ISOFiles[$numInput - 1].Name
        } elseif ($ISOinput -eq "c") {
            Exit
        } else {
            Write-Host "Invalid selection, please try again" -ForegroundColor Red
        }
    }
}