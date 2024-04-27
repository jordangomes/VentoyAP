$module = Import-Module Communary.PASM -PassThru -ErrorAction Ignore
if (-not $module) {
    Write-Host "Installing Required Modules" -ForegroundColor Green
    $provider = Get-PackageProvider NuGet -ErrorAction Ignore
    if (-not $provider) {
        Write-Host "Installing provider NuGet"
        Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
    }
    Write-Host "Installing Communary.PASM"
    Install-Module Communary.PASM -Force
}
Import-Module Communary.PASM
<#
    .Synopsis
    Allows selection of a single item from a list of items.

    .Description
    Displays an array of strings and allows for the selection of a single item.
    the result is returned as the index of the selected item

    .PARAMETER Title
    The title to display at the top of the list.

    .PARAMETER Items
    An array of strings to display in the list.

    .PARAMETER ForegroundColor
    The foreground color of the unselected items.

    .PARAMETER BackgroundColor
    The background color of the unselected items.

    .PARAMETER TitleForegroundColor
    The foreground color of the title. - If left empty or white is selected  will use default console colors

    .PARAMETER TitleBackgroundColor
    The background color of the title.

    .PARAMETER SelectedForegroundColor
    The foreground color of the selected item.

    .PARAMETER SelectedBackgroundColor
    The background color of the selected item.

    .PARAMETER SelectedPrefix
    A string to prepend to the selected item.

    .PARAMETER SelectedSuffix
    A string to append to the selected item.

    .PARAMETER AllowCancel
    If present, adds a "Cancel" option to the list. If selected, returns $null.

    .PARAMETER CancelText
    If present, adds a "Cancel" option to the list. If selected, returns $null.
    
#>
function Get-ListSelection {
    param(
        [string] $Title = "Select an item",
        [Parameter(Mandatory)][string[]] $Items,
        [System.ConsoleColor] $ForegroundColor = "White",
        [System.ConsoleColor] $BackgroundColor = "Black",
        [System.ConsoleColor] $TitleForegroundColor = "White",
        [System.ConsoleColor] $TitleBackgroundColor = "Black",
        [System.ConsoleColor] $SelectedForegroundColor = "Black",
        [System.ConsoleColor] $SelectedBackgroundColor = "Green",
        [string] $SelectedPrefix = "> ",
        [string] $SelectedSuffix = "",
        [switch] $AllowCancel,
        [string] $CancelText = "Cancel"
    )
    $Selection = 0
    $EnterPressed = $False
    $UnselectedPrefix = @(0..($SelectedPrefix.Length - 1) | ForEach-Object { " " }) -join ""
    $UnselectedSuffix = @(0..($SelectedSuffix.Length - 1) | ForEach-Object { " " }) -join ""

    if ($AllowCancel) {
        $Items += $CancelText
    }

    Clear-Host
    while (-not $EnterPressed) {
        if($TitleForegroundColor -eq "White"){
            Write-Host $Title
        } else {
            Write-Host $Title -ForegroundColor $TitleForegroundColor -BackgroundColor $TitleBackgroundColorr
        }
        
        for ($i = 0; $i -lt $Items.Length; $i++) {
            $OveridableForegroundColor = $ForegroundColor
            if($AllowCancel -and $i -eq $Items.Length - 1){
                $OveridableForegroundColor = "Red"
            }

            if ($i -eq $Selection) {
                Write-Host "$SelectedPrefix$($Items[$i])$SelectedSuffix" -ForegroundColor $SelectedForegroundColor -BackgroundColor $SelectedBackgroundColor
            } else {
                Write-Host "$UnselectedPrefix$($Items[$i])$UnselectedSuffix" -ForegroundColor $OveridableForegroundColor -BackgroundColor $BackgroundColor
            }
        }
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
        switch ($Key) {
            13{
                $EnterPressed = $True
                if($AllowCancel -and $Selection -eq $Items.Length - 1){
                    return $null
                }
                return $Selection
            }

            38{
                If ($Selection -eq 0){
                    $Selection = $Items.Length - 1
                } Else {
                    $Selection -= 1
                }
                Clear-Host
                break
            }

            40{
                If ($Selection -eq $Items.Length - 1){
                    $Selection = 0
                } Else {
                    $Selection +=1
                }
                Clear-Host
                break
            }
            Default{
                Clear-Host
            }
        }
    }
}


<#
    .Synopsis
    Allows selection of multiple items from a list of items.

    .Description
    Displays an array of strings and allows for the selection of multiple items using space bar
    the result is returned as an array of indexes of the selected items

    .PARAMETER Title
    The title to display at the top of the list.

    .PARAMETER Items
    An array of strings to display in the list.

    .PARAMETER PreselectedItems
    An array of indexes for items that are already selected

    .PARAMETER ForegroundColor
    The foreground color of the unselected items.

    .PARAMETER BackgroundColor
    The background color of the unselected items.

    .PARAMETER TitleForegroundColor
    The foreground color of the title. - If left empty or white is selected  will use default console colors

    .PARAMETER TitleBackgroundColor
    The background color of the title.

    .PARAMETER CursorForegroundColor
    The foreground color of the item under the cursor.

    .PARAMETER CursorBackgroundColor
    The background color of the item under the cursor.

    .PARAMETER SelectedForegroundColor
    The foreground color of the selected item.

    .PARAMETER SelectedBackgroundColor
    The background color of the selected item.

    .PARAMETER SelectedPrefix
    A string to prepend to the selected item.

    .PARAMETER SelectedSuffix
    A string to append to the selected item.

    .PARAMETER AllowNone
    If present allows for no items item to be selected returns an empty array

    .PARAMETER AllowCancel
    If present, adds a "Cancel" option to the list. If selected, returns $null.
    
#>
function Get-ListMultipleSelection {
    param(
        [string] $Title = "Select multiple items (Space to select, Enter to confirm)",
        [Parameter(Mandatory)][string[]] $Items,
        [int[]] $PreselectedItems = @(),
        [System.ConsoleColor] $ForegroundColor = "White",
        [System.ConsoleColor] $BackgroundColor = "Black",
        [System.ConsoleColor] $TitleForegroundColor = "White",
        [System.ConsoleColor] $TitleBackgroundColor = "Black",
        [System.ConsoleColor] $CursorForegroundColor = "Black",
        [System.ConsoleColor] $CursorBackgroundColor = "Green",
        [System.ConsoleColor] $SelectedForegroundColor = "Green",
        [System.ConsoleColor] $SelectedBackgroundColor = "Black",
        [string] $SelectedPrefix = "> ",
        [string] $SelectedSuffix = "  ",
        [switch] $AllowNone,
        [switch] $AllowCancel
    )
    $SelectedItems = $PreselectedItems
    $draw = $true
    $Cursor = 0
    $UnselectedPrefix = @(0..($SelectedPrefix.Length - 1) | ForEach-Object { " " }) -join ""
    $UnselectedSuffix = @(0..($SelectedSuffix.Length - 1) | ForEach-Object { " " }) -join ""

    if ($AllowCancel) {
        $Items += "Cancel"
    }

    Clear-Host
    while ($true) {
        if($draw) {
            if($TitleForegroundColor -eq "White"){
                Write-Host $Title
            } else {
                Write-Host $Title -ForegroundColor $TitleForegroundColor -BackgroundColor $TitleBackgroundColorr
            }
            for ($i = 0; $i -lt $Items.Length; $i++) {
                $OveridableForegroundColor = $ForegroundColor
                if($AllowCancel -and $i -eq $Items.Length - 1){
                    $OveridableForegroundColor = "Red"
                }
                
                if ($SelectedItems -contains $i -and $i -eq $Cursor) {
                    Write-Host "$SelectedPrefix$($Items[$i])$SelectedSuffix" -ForegroundColor $CursorForegroundColor -BackgroundColor $CursorBackgroundColor
                } elseif($SelectedItems -contains $i -and $i -ne $Cursor){
                    Write-Host "$SelectedPrefix$($Items[$i])$SelectedSuffix" -ForegroundColor $SelectedForegroundColor -BackgroundColor $SelectedBackgroundColor
                } elseif($i -eq $Cursor){
                    Write-Host "$UnselectedPrefix$($Items[$i])$UnselectedSuffix" -ForegroundColor $CursorForegroundColor -BackgroundColor $CursorBackgroundColor
                } else{
                    Write-Host "$UnselectedPrefix$($Items[$i])$UnselectedSuffix" -ForegroundColor $OveridableForegroundColor -BackgroundColor $BackgroundColor
                }
            }
        }
        
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
        switch ($Key) {
            13{
                if($AllowCancel -and $Cursor -eq $Items.Length - 1){
                    return $null
                }
                if($SelectedItems.Length -ne 0){
                    return $SelectedItems
                } elseif($AllowNone){
                    Write-Host "Selected items length: $($SelectedItems.Length)"
                    return ,$SelectedItems
                } else {
                    [console]::beep(400,100)
                    $draw = $false
                }
                
            }

            32 {
                if($AllowCancel -and $Cursor -eq $Items.Length - 1){
                    return $null
                }
                if($SelectedItems -contains $Cursor){
                    $SelectedItems = @($SelectedItems | Where-Object {$_ -ne $Cursor})
                } else {
                    $SelectedItems += $Cursor
                }
                $draw = $true
                Clear-Host
                break
            }

            38{
                If ($Cursor -eq 0){
                    $Cursor = $Items.Length - 1
                } Else {
                    $Cursor -= 1
                }
                $draw = $true
                Clear-Host
                break
            }

            40{
                If ($Cursor -eq $Items.Length - 1){
                    $Cursor = 0
                } Else {
                    $Cursor +=1
                }
                $draw = $true
                Clear-Host
                break
            }
            Default{
                Clear-Host
            }
        }
    }
}

function Search-List {
    param (
        [string] $Prompt = "Search for a item",
        [Parameter(Mandatory)][string[]] $Items,
        [int] $MaxResults = 10,
        [System.ConsoleColor] $ForegroundColor = "White",
        [System.ConsoleColor] $BackgroundColor = "Black",
        [System.ConsoleColor] $TitleForegroundColor = "White",
        [System.ConsoleColor] $TitleBackgroundColor = "Black",
        [System.ConsoleColor] $SelectedForegroundColor = "Black",
        [System.ConsoleColor] $SelectedBackgroundColor = "Green",
        [string] $SelectedPrefix = "> ",
        [string] $SelectedSuffix = "  ",
        [switch] $AllowCancel
    )

    if($AllowCancel) {
        $Prompt = "$Prompt (or press esc to cancel)"
    }

    Clear-Host
    if($TitleForegroundColor -eq "White"){
        Write-Host "$Prompt`: "
    } else {
        Write-Host "$Prompt`: " -ForegroundColor $TitleForegroundColor -BackgroundColor $TitleBackgroundColor 
    }
    Write-Host "Type to search" -ForegroundColor "DarkGray"

    $Buffer = ""
    $LastBuffer = ""
    $LastBufferDisplay = ""
    $Redraw = $FALSE
    $SearchResults = @()
    $Selection = -1
    $UnselectedPrefix = @(0..($SelectedPrefix.Length - 1) | ForEach-Object { " " }) -join ""
    $UnselectedSuffix = @(0..($SelectedSuffix.Length - 1) | ForEach-Object { " " }) -join ""
    $debounceTimer = [Diagnostics.Stopwatch]::StartNew()
    $searchDebounceTimer = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if([Console]::KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.VirtualKeyCode -eq 8) {
                if ($Buffer.Length) { $Buffer = $Buffer.Substring(0, $Buffer.Length-1) }
            } elseif ($key.VirtualKeyCode -eq 13) {
                if($Selection -eq -1) {
                    [console]::beep(400,100)
                } else {
                    return $SearchResults[$Selection]
                }
            } elseif($key.VirtualKeyCode -eq 27 -and $AllowCancel) {
                return $null
            } elseif ($key.VirtualKeyCode -eq 38){
                if ($Selection -le 0){
                    $Selection = $SearchResults.Length - 1
                } else {
                    $Selection -= 1
                }
                $Redraw = $TRUE
            } elseif($key.VirtualKeyCode -eq 40){
                if ($Selection -ge $SearchResults.Length - 1){
                    $Selection = 0
                } else {
                    $Selection +=1
                }
                $Redraw = $TRUE
            } else {
                if(Get-ValidSearchKey -Char $key.VirtualKeyCode) {
                    $Buffer += $key.Character
                }
            }
        }
        if($searchDebounceTimer.ElapsedMilliseconds -gt 200 -and $Buffer -ne $LastBuffer) {
            $searchDebounceTimer.Restart()
            $LastBuffer = $Buffer
            $Selection = -1
            $SearchResults = Get-ItemIndexesFuzzyMatch -Items $Items -SearchString $Buffer | Select-Object -First $MaxResults
            $Redraw = $TRUE
        }
        if($debounceTimer.ElapsedMilliseconds -gt 50 -and ($Buffer -ne $LastBufferDisplay -or $Redraw)) {
            $debounceTimer.Restart()
            $LastBufferDisplay = $Buffer
            $Redraw = $FALSE

            Clear-Host
            if($TitleForegroundColor -eq "White"){
                Write-Host "$Prompt`: " -NoNewline
            } else {
                Write-Host "$Prompt`: " -NoNewline -ForegroundColor $TitleForegroundColor -BackgroundColor $TitleBackgroundColor 
            }
            Write-Host "$Buffer" -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor

            if($SearchResults.Length -gt 0) {
                foreach($result in $SearchResults){
                    if ($result -eq $SearchResults[$Selection] -and $Selection -ne -1) {
                        Write-Host "$SelectedPrefix$($Items[$result])$SelectedSuffix" -ForegroundColor $SelectedForegroundColor -BackgroundColor $SelectedBackgroundColor
                    } else {
                        Write-Host "$UnselectedPrefix$($Items[$result])$UnselectedSuffix" -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
                    }
                }
            } elseif ([string]::IsNullOrEmpty($Buffer)){
                Write-Host "Type to search" -ForegroundColor "DarkGray"
            } else {
                Write-Host "No results found" -ForegroundColor "Red"
            }
        }
    }
}

function Get-ValidSearchKey {
    param (
        [int]$Char
    )
    if($Char -eq 32){
        return $true
    } if ($Char -ge 48 -and $Char -le 57) {
        return $true
    } elseif ($Char -ge 65 -and $Char -le 90) {
        return $true
    } elseif ($Char -ge 99 -and $Char -le 105) {
        return $true
    } elseif ($Char -ge 188 -and $Char -le 190) {
        return $true
    }

    return $false
}

function Get-ItemIndexesFuzzyMatch {
    param (
        [Parameter(Mandatory)][string[]] $Items,
        [string] $SearchString
    )

    if([string]::IsNullOrEmpty($SearchString)) {
        return @()
    }
    $search = $SearchString.Replace(' ','')
    $quickSearchFilter = '*'
    $search.ToCharArray().ForEach({
        $quickSearchFilter += $_ + '*'
    })
    $results = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $string = $Items[$i].Trim()
        if($string -like $quickSearchFilter) {
            $results += @{
                index = $i;
                score = Get-FuzzyMatchScore -Search $SearchString -String $string
            }
        }
    }
    
    
    if($results.Count -gt 0) {
        $results = $results | Sort-Object -Property score -Descending | Select-Object -ExpandProperty index
    } else {
        return @()
    }

    return $results
}

function Get-YesNo {
    param(
        [string] $Prompt = "Yes (y) | No (n)",
        [System.ConsoleColor] $TitleForegroundColor = "White",
        [System.ConsoleColor] $TitleBackgroundColor = "Black",
        [switch] $Inline,
        [switch] $AllowCancel
    )

    if(-not $Inline) {
        Clear-Host
    }

    if($AllowCancel -and $Prompt -eq "Yes (y) | No (n)") {
        $Prompt = "Yes (y) | No (n) | Cancel (esc)"
    }

    if($TitleForegroundColor -eq "White"){
        Write-Host $Prompt
    } else {
        Write-Host $Prompt -ForegroundColor $TitleForegroundColor -BackgroundColor $TitleBackgroundColor
    }
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if($key.VirtualKeyCode -eq 89) {
            return $true
        } elseif($key.VirtualKeyCode -eq 78){
            return $false
        } elseif ($key.VirtualKeyCode -eq 27 -and $AllowCancel) {
            return $null
        } else {
            [console]::beep(400,100)
        }
    }

}

Export-ModuleMember -Function Get-ListSelection
Export-ModuleMember -Function Get-ListMultipleSelection
Export-ModuleMember -Function Search-List
Export-ModuleMember -Function Get-YesNo


