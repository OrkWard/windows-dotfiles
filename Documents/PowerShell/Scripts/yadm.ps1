# yadm.ps1 - Yet Another Dotfiles Manager for Windows
# Usage: yadm.ps1 <git-command> [arguments...]
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$GitArgs
)

$yadmGitDir = Join-Path $env:USERPROFILE ".local\share\yadm\repo.git"

function Invoke-YadmGit {
    param([string[]]$Arguments)
    & git --git-dir=$yadmGitDir --work-tree=$env:USERPROFILE @Arguments
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not found in PATH"
    exit 1
}

if ($GitArgs.Count -eq 0 -or $GitArgs[0] -eq "init") {
    & git init --bare $yadmGitDir
    Invoke-YadmGit @("config", "--local", "status.showUntrackedFiles", "no")
    exit 0
}

if ($GitArgs.Count -gt 0) {
    Invoke-YadmGit $GitArgs
} else {
    Write-Host "Usage: yadm.ps1 <git-command> [arguments...]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  yadm.ps1 init"
    Write-Host "  yadm.ps1 status"
    Write-Host "  yadm.ps1 add .gitconfig"
    Write-Host "  yadm.ps1 commit -m 'Add gitconfig'"
    Write-Host "  yadm.ps1 push"
}
