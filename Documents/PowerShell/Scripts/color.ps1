function Show-Color256 {
    $colors = @(
        @{Code=30; Name="Black"},
        @{Code=31; Name="Red"},
        @{Code=32; Name="Green"},
        @{Code=33; Name="Yellow"},
        @{Code=34; Name="Blue"},
        @{Code=35; Name="Magenta"},
        @{Code=36; Name="Cyan"},
        @{Code=37; Name="White"},
        @{Code=90; Name="BrightBlack"},
        @{Code=91; Name="BrightRed"},
        @{Code=92; Name="BrightGreen"},
        @{Code=93; Name="BrightYellow"},
        @{Code=94; Name="BrightBlue"},
        @{Code=95; Name="BrightMagenta"},
        @{Code=96; Name="BrightCyan"},
        @{Code=97; Name="BrightWhite"}
    )

    Write-Host -NoNewline "    "
    
    foreach ($color in $colors) {
        Write-Host -NoNewline "$($color.Code.ToString().PadRight(4))"
    }
    Write-Host -NoNewline "`n"

    foreach ($color in $colors) {
        Write-Host -NoNewline "$(($color.Code + 10).ToString().PadRight(4))"
        foreach ($fg in $colors) {
            Write-Host -NoNewline "`e[$($fg.Code);$($color.Code + 10)m A `e[0m "
        }
        Write-Host -NoNewline "`n"
    }
}
