function Show-AnsiColorsDetailed {
    Write-Host "`n=== ANSI Color Reference ===" -ForegroundColor Cyan
    
    # 基础颜色名称
    Write-Host "`n--- Named Colors ---"
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
    
    foreach ($color in $colors) {
        $fg = "`e[$($color.Code)m"
        $bg = "`e[$($color.Code + 10)m"
        Write-Host "$fg█████`e[0m $bg     `e[0m  $($color.Name.PadRight(15)) FG: ``e[$($color.Code)m  BG: ``e[$($color.Code + 10)m"
    }
    
    # 256 色网格
    Write-Host "`n--- 256 Colors (0-255) ---"
    Write-Host "Hover format: ``e[38;5;Nm (foreground) or ``e[48;5;Nm (background)`n"
    
    0..255 | ForEach-Object {
        $num = $_.ToString().PadLeft(3)
        Write-Host -NoNewline "`e[48;5;${_}m $num `e[0m"
        
        if (($_ + 1) % 16 -eq 0) { 
            Write-Host "" 
        } elseif (($_ + 1) % 8 -eq 0) {
            Write-Host -NoNewline "  "
        }
    }
    
    Write-Host "`n"
}
