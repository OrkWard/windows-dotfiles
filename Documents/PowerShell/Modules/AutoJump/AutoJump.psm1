# AutoJump PowerShell Integration
# 设置环境变量标记
$env:AUTOJUMP_SOURCED = 1

# 设置用户安装路径
$autoJumpPath = Join-Path $env:USERPROFILE ".autojump"
if (Test-Path $autoJumpPath) {
    $env:PATH = "$autoJumpPath\bin;$env:PATH"
}

# 设置错误日志文件路径
if ($env:XDG_DATA_HOME) {
    $script:AUTOJUMP_ERROR_PATH = Join-Path $env:XDG_DATA_HOME "autojump\errors.log"
} else {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $script:AUTOJUMP_ERROR_PATH = Join-Path $localAppData "autojump\errors.log"
}

# 确保错误日志目录存在
$errorDir = Split-Path $script:AUTOJUMP_ERROR_PATH -Parent
if (-not (Test-Path $errorDir)) {
    New-Item -ItemType Directory -Path $errorDir -Force | Out-Null
}

# Tab 自动补全
Register-ArgumentCompleter -CommandName j, jc -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    $completions = & autojump --complete $wordToComplete 2>$null
    if ($completions) {
        $completions -split "`n" | Where-Object { $_ } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# 添加当前目录到数据库的函数
function Add-AutoJumpPath {
    $currentPath = Get-Location | Select-Object -ExpandProperty Path
    if (Test-Path $script:AUTOJUMP_ERROR_PATH) {
        Start-Job -ScriptBlock {
            param($path, $errorPath)
            & autojump --add $path 2>> $errorPath | Out-Null
        } -ArgumentList $currentPath, $script:AUTOJUMP_ERROR_PATH | Out-Null
    } else {
        Start-Job -ScriptBlock {
            param($path)
            & autojump --add $path 2>$null | Out-Null
        } -ArgumentList $currentPath | Out-Null
    }
}

# 设置 Prompt 钩子来跟踪目录变化
$global:AutoJumpPromptAdded = $false
if (-not $global:AutoJumpPromptAdded) {
    $existingPrompt = Get-Content Function:\prompt -ErrorAction SilentlyContinue
    
    function global:prompt {
        Add-AutoJumpPath
        if ($existingPrompt) {
            & $existingPrompt
        } else {
            "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
        }
    }
    
    $global:AutoJumpPromptAdded = $true
}

# 主要的 j 函数 - 跳转到目录
function j {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    
    # 如果是选项参数，直接传递给 autojump
    if ($Arguments -and $Arguments[0] -match '^-' -and $Arguments[0] -ne '--') {
        & autojump $Arguments
        return
    }
    
    # 获取 autojump 输出
    $output = & autojump $Arguments 2>&1
    
    if (Test-Path $output -PathType Container) {
        # 输出彩色路径（如果支持）
        if ($Host.UI.SupportsVirtualTerminal) {
            Write-Host "`e[31m$output`e[0m"
        } else {
            Write-Host $output -ForegroundColor Red
        }
        Set-Location $output
    } else {
        Write-Host "autojump: directory '$Arguments' not found" -ForegroundColor Yellow
        Write-Host "`n$output`n"
        Write-Host "Try 'autojump --help' for more information."
        $global:LASTEXITCODE = 1
    }
}

# jc 函数 - 跳转到当前目录的子目录
function jc {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    
    if ($Arguments -and $Arguments[0] -match '^-' -and $Arguments[0] -ne '--') {
        & autojump $Arguments
        return
    }
    
    $currentPath = Get-Location | Select-Object -ExpandProperty Path
    j $currentPath $Arguments
}

# jo 函数 - 在文件浏览器中打开目录
function jo {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    
    if ($Arguments -and $Arguments[0] -match '^-' -and $Arguments[0] -ne '--') {
        & autojump $Arguments
        return
    }
    
    $output = & autojump $Arguments 2>&1
    
    if (Test-Path $output -PathType Container) {
        if ($IsWindows -or $env:OS -match "Windows") {
            Start-Process explorer.exe $output
        } elseif ($IsMacOS) {
            Start-Process open $output
        } elseif ($IsLinux) {
            Start-Process xdg-open $output
        } else {
            Write-Host "Unknown operating system." -ForegroundColor Red
        }
    } else {
        Write-Host "autojump: directory '$Arguments' not found" -ForegroundColor Yellow
        Write-Host "`n$output`n"
        Write-Host "Try 'autojump --help' for more information."
        $global:LASTEXITCODE = 1
    }
}

# jco 函数 - 在文件浏览器中打开子目录
function jco {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    
    if ($Arguments -and $Arguments[0] -match '^-' -and $Arguments[0] -ne '--') {
        & autojump $Arguments
        return
    }
    
    $currentPath = Get-Location | Select-Object -ExpandProperty Path
    jo $currentPath $Arguments
}

# 导出函数
Export-ModuleMember -Function j, jc, jo, jco

Write-Host "AutoJump PowerShell integration loaded. Use 'j <directory>' to jump." -ForegroundColor DarkGreen
