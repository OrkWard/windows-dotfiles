# config.nu
#
# Installed by:
# version = "0.115.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings,
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

$env.XDG_CONFIG_HOME = ($env.USERPROFILE | path join '.config')
$env.XDG_DATA_HOME = ($env.USERPROFILE | path join '.local' 'share')
$env.XDG_STATE_HOME = ($env.USERPROFILE | path join '.local' 'state')
$env.XDG_CACHE_HOME = ($env.USERPROFILE | path join '.cache')

$env.config.use_ansi_coloring = true
$env.config.ls.use_ls_colors = true
$env.LS_COLORS = ([
    'no=0' 'fi=0'
    'di=1;34' 'ln=1;36' 'ex=1;32'
    'or=1;31' 'mi=1;31'
    'pi=33' 'so=1;35' 'bd=1;33' 'cd=1;33'
    'su=37;41' 'sg=30;43' 'tw=30;42' 'ow=34;42' 'st=37;44'
    '*.c=36' '*.h=36' '*.cpp=36' '*.rs=36' '*.go=36'
    '*.py=36' '*.js=36' '*.ts=36' '*.tsx=36' '*.lua=36' '*.nu=36' '*.sh=36'
    '*.json=33' '*.yaml=33' '*.yml=33' '*.toml=33' '*.ini=33' '*.cfg=33'
    '*.md=33' '*.txt=33'
    '*.7z=1;31' '*.bz2=1;31' '*.gz=1;31' '*.rar=1;31' '*.tar=1;31' '*.tgz=1;31' '*.xz=1;31' '*.zip=1;31' '*.zst=1;31'
    '*.gif=35' '*.jpeg=35' '*.jpg=35' '*.png=35' '*.svg=35' '*.webp=35'
    '*.avi=35' '*.mkv=35' '*.mov=35' '*.mp4=35' '*.webm=35'
    '*.flac=35' '*.m4a=35' '*.mp3=35' '*.ogg=35' '*.wav=35'
    '*.bak=90' '*.log=90' '*~=90'
] | str join ':')

# Expose only the currently running command to WezTerm's session snapshot.
def __wezterm-set-user-var [name: string, value: string] {
    if ($env.TERM_PROGRAM? != 'WezTerm') {
        return
    }
    let encoded = ($value | encode base64)
    print -n $'(ansi osc)1337;SetUserVar=($name)=($encoded)(char bel)'
}

$env.config.hooks.pre_execution = (
    $env.config.hooks.pre_execution
    | append {||
        __wezterm-set-user-var WEZTERM_LAST_COMMAND (commandline)
    }
)

$env.config.hooks.pre_prompt = (
    $env.config.hooks.pre_prompt
    | append {||
        __wezterm-set-user-var WEZTERM_LAST_COMMAND ''
        if 'WEZTERM_RESTORE_COMMAND' in $env {
            let restored = $env.WEZTERM_RESTORE_COMMAND
            hide-env WEZTERM_RESTORE_COMMAND
            commandline edit --replace $restored
        }
    }
)

alias ll = ls -al

alias ga = git add --all
alias gau = git add --update
alias gc = git commit
alias gcm = git commit --message
alias gs = git status
alias gsw = git switch
alias gsm = git switch master
alias gd = git diff
alias gds = git diff --staged
alias gl = git pull
alias gp = git push
alias gca = git commit --amend
alias gpf = git push --force-with-lease

def copy []: any -> nothing {
    let input = ($in | into string)
    let encoded = ($input | encode base64)
    print -n $'(ansi osc)52;c;($encoded)(char bel)'
}

source .\zoxide.nu
