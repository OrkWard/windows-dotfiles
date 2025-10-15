Import-Module AutoJump

$Env:http_proxy="http://acer:7890";$Env:https_proxy="http://acer:7890"
$Env:EDITOR="zed -w"

$PSReadLineOptions = @{
    EditMode = 'Emacs'
    BellStyle = 'None'
    PredictionSource = 'None'
    Colors = @{
        ContinuationPrompt = 'Black'
        Emphasis = 'DarkMagenta'
        Error = 'DarkRed'
        Selection = 'DarkBlue'
        Default = 'Black'
        Comment = 'DarkGray'
        Keyword = 'Magenta'
        String = 'DarkGreen'
        Operator = 'DarkRed'
        Variable = 'DarkRed'
        Command = 'DarkBlue'
        Parameter = 'DarkYellow'
        Type = 'DarkYellow'
        Number = 'DarkGreen'
        Member = 'DarkCyan'
        InlinePrediction = 'Blue'
        ListPrediction = 'Blue'
        ListPredictionSelected = 'DarkBlue'
    }
}
Set-PSReadLineOption @PSReadLineOptions

$PSStyle.FileInfo.Directory = "`e[34m"
$PSStyle.FileInfo.SymbolicLink = "`e[35m"
$PSStyle.FileInfo.Executable = "`e[32m"
$PSStyle.Formatting.TableHeader = "`e[36m"
$PSStyle.Formatting.FeedbackAction = "`e[35m"

# Visual Studio 2022 Developer Environment Function
function Enable-VsDev {
    param([string]$Arch = "x64")
    
    $vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"
    $dllPath = "$vsPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    
    if (Test-Path $dllPath) {
        Import-Module $dllPath
        Enter-VsDevShell -VsInstallPath $vsPath `
                         -SkipAutomaticLocation `
                         -DevCmdArguments "-arch=$Arch -host_arch=$Arch"
    } else {
        Write-Host "Visual Studio 2022 not found at $vsPath" -ForegroundColor Red
    }
}

. "$env:USERPROFILE\Documents\PowerShell\Scripts\color.ps1"

function yadm {
    & "$env:USERPROFILE\Documents\PowerShell\Scripts\yadm.ps1" @args
}
function ya { yadm add $args }
function yc { yadm commit }
function ys { yadm status }
function yp { yadm push }

function vp { gvim $PROFILE }
function vv { gvim $HOME/vimfiles/vimrc }

# alias
Set-Alias -Name which -Value Get-Command
