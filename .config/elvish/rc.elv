# rc.elv: ported from ~/.config/nushell, aligned with ~/Repos/dotfiles fish config.

use os
use path
use platform
use re
use str
use ./osc
use ./dirhist

# ==================== env =====================
fn -home {|@p| path:join ~ $@p }

set E:XDG_CONFIG_HOME = (-home .config)
set E:XDG_DATA_HOME = (-home .local share)
set E:XDG_STATE_HOME = (-home .local state)
set E:XDG_CACHE_HOME = (-home .cache)
set E:XDG_RUNTIME_DIR = (-home .local tmp)

set E:CARGO_HOME = (-home .local share cargo)
set E:RUSTUP_HOME = (-home .local share rustup)
set E:MC_CONFIG_DIR = (-home .local share mc)
set E:GOPATH = (-home .local go)
set E:GOPROXY = 'https://goproxy.cn,direct'
set E:NIMBLE_DIR = (path:join $E:XDG_DATA_HOME nimble)

set E:EDITOR = nvim
set E:BAT_THEME = GitHub
set E:VIFM = (-home .config vifm)
set E:GCC_COLORS = 'error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

set E:HTTP_PROXY = 'http://proxy.lan:9090'
set E:HTTPS_PROXY = 'http://proxy.lan:9090'
set E:ALL_PROXY = 'http://proxy.lan:9090'
set E:NO_PROXY = 'localhost,127.0.0.1,::1,.lan,192.168.88.0/24,192.168.136.0/24'
# Node >= 24.5 built-in fetch/http only honors *_PROXY when this is set
set E:NODE_USE_ENV_PROXY = 1

set E:LS_COLORS = (str:join ':' [
  no=0 fi=0
  'di=1;34' 'ln=1;36' 'ex=1;32'
  'or=1;31' 'mi=1;31'
  pi=33 'so=1;35' 'bd=1;33' 'cd=1;33'
  'su=37;41' 'sg=30;43' 'tw=30;42' 'ow=34;42' 'st=37;44'
  '*.c=36' '*.h=36' '*.cpp=36' '*.rs=36' '*.go=36'
  '*.py=36' '*.js=36' '*.ts=36' '*.tsx=36' '*.lua=36' '*.nu=36' '*.sh=36' '*.elv=36'
  '*.json=33' '*.yaml=33' '*.yml=33' '*.toml=33' '*.ini=33' '*.cfg=33'
  '*.md=33' '*.txt=33'
  '*.7z=1;31' '*.bz2=1;31' '*.gz=1;31' '*.rar=1;31' '*.tar=1;31' '*.tgz=1;31' '*.xz=1;31' '*.zip=1;31' '*.zst=1;31'
  '*.gif=35' '*.jpeg=35' '*.jpg=35' '*.png=35' '*.svg=35' '*.webp=35'
  '*.avi=35' '*.mkv=35' '*.mov=35' '*.mp4=35' '*.webm=35'
  '*.flac=35' '*.m4a=35' '*.mp3=35' '*.ogg=35' '*.wav=35'
  '*.bak=90' '*.log=90' '*~=90'
])

# ==================== path ====================
# Prepend, then drop duplicates (case-insensitive), keeping the first one.
fn -uniq-paths {|@dirs|
  var seen = [&]
  for d $dirs {
    var d = (path:clean $d)
    var k = (str:to-lower $d)
    if (not (has-key $seen $k)) {
      set seen[$k] = $true
      put $d
    }
  }
}

set paths = [(-uniq-paths ^
  (-home scoop shims) ^
  (-home scoop apps wezterm-nightly current) ^
  (-home .local bin) ^
  (path:join $E:GOPATH bin) ^
  (path:join $E:CARGO_HOME bin) ^
  $@paths)]

# ================ prompt ===================
# Disable cursor blinking.
print "\e[?12l"

var -last-status = 0
set edit:after-command = [$@edit:after-command {|m|
  var e = $m[error]
  if (eq $e $nil) {
    set -last-status = 0
  } else {
    try {
      if (eq $e[reason][type] external-cmd/exited) {
        set -last-status = $e[reason][exit-status]
      } else {
        set -last-status = 1
      }
    } catch {
      set -last-status = 1
    }
  }
}]

# fish's prompt_pwd: abbreviate every component but the last to one character.
fn -prompt-pwd {
  var parts = [(str:split $path:separator (tilde-abbr $pwd))]
  var n = (count $parts)
  var out = [(range (- $n 1) | each {|i|
    var s = $parts[$i]
    if (or (eq $s '') (str:has-suffix $s ':')) {
      put $s
    } else {
      re:replace '^(\.?.).*$' '$1' $s
    }
  }) $parts[-1]]
  str:join $path:separator $out
}

fn -git-branch {
  try {
    var b = (git rev-parse --abbrev-ref HEAD 2>$os:dev-null)
    if (eq $b HEAD) {
      set b = (git rev-parse --short HEAD 2>$os:dev-null)
    }
    put $b
  } catch { }
}

var -host = (platform:hostname &strip-domain)

set edit:prompt = {
  styled $E:USERNAME'@'$-host' ' green
  styled (-prompt-pwd)' ' blue
  var b = [(-git-branch)]
  if (> (count $b) 0) {
    styled '('$b[0]') ' magenta
  }
  styled '['$-last-status'] '(date +%H:%M:%S) yellow
  put "\n$ "
}
set edit:rprompt = (constantly '')

# ================ abbr ===================
set edit:command-abbr = [
  # handy
  &rmf='rm -rf'
  &mkdir='mkdir -p'

  # cd
  &'..'='cd ..'
  &'...'='cd ../..'
  &'....'='cd ../../..'

  # vim
  &v=nvim

  # yadm
  &ys='yadm status'
  &yd='yadm diff'
  &yds='yadm diff --staged'
  &yl='yadm pull'
  &yp='yadm push'

  # ls
  &l=ls
  &ll='ls -alhF'
  &la='ls -a'

  # git
  &ga='git add -A'
  &gau='git add -u'
  &gc='git commit'
  &gcm='git commit -m'
  &gs='git status'
  &gsw='git switch'
  &gsm='git switch master'
  &gd='git diff'
  &gds='git diff --staged'
  &gl='git pull'
  &gp='git push'
  &gca='git commit --amend'
  &gpf='git push --force-with-lease'
  &gxp='git xpush'

  # docker
  &dc='docker compose'
]

# fish: abbr p0 --position anywhere
set edit:small-word-abbr = [
  &p0='>$os:dev-null 2>&1'
]

# ================ functions ===================
fn -now { date '+%Y-%m-%d %H:%M:%S' }

# yadm is a nushell script in ~/.local/bin.
fn yadm {|@args|
  nu (-home .local bin yadm.nu) $@args
}

fn gac {
  git add .
  git commit --message (-now)
}

fn yac {
  yadm add --update
  yadm commit --message (-now)
}

# Pipe stdin to the system clipboard.
fn copy {
  osc:copy (slurp)
}

# ================ key bindings ===================
# Ctrl-T: pick a file with fd and insert it at the cursor.
set edit:insert:binding[Ctrl-T] = {
  var items = [(fd --type f --hidden --follow --exclude .git | each {|f|
    put [&to-show=$f &to-filter=(str:to-lower $f) &to-accept=$f]
  })]
  edit:listing:start-custom $items &caption=' FILES ' &accept={|f|
    edit:insert-at-dot (repr $f)
  }
}

# Ctrl-R: history list. Enter runs the entry, Tab only puts it on the line,
# Esc restores the original line.
var -saved-line = ''
set edit:insert:binding[Ctrl-R] = {
  set -saved-line = $edit:current-command
  set edit:current-command = ''
  edit:histlist:start
}
set edit:histlist:binding[Enter] = {
  edit:listing:accept
  edit:return-line
}
set edit:histlist:binding[Tab] = $edit:listing:accept~
set edit:histlist:binding[Ctrl-'['] = {
  edit:close-mode
  set edit:current-command = $-saved-line
}

# Alt-Left / Alt-Right: prevd / nextd on an empty line, word movement otherwise.
set edit:insert:binding[Alt-Left] = {
  if (eq $edit:current-command '') {
    dirhist:prevd
  } else {
    edit:move-dot-left-word
  }
}
set edit:insert:binding[Alt-Right] = {
  if (eq $edit:current-command '') {
    dirhist:nextd
  } else {
    edit:move-dot-right-word
  }
}

# ================ hooks ===================
# Expose only the currently running command to WezTerm's session snapshot.
set edit:after-readline = [$@edit:after-readline {|line|
  osc:set-user-var WEZTERM_LAST_COMMAND $line
}]
set edit:before-readline = [$@edit:before-readline {
  osc:set-user-var WEZTERM_LAST_COMMAND ''
  if (has-env WEZTERM_RESTORE_COMMAND) {
    set edit:current-command = $E:WEZTERM_RESTORE_COMMAND
    unset-env WEZTERM_RESTORE_COMMAND
  }
}]

# direnv (from `direnv hook elvish`)
set edit:before-readline = [$@edit:before-readline {
  try {
    var m = [(direnv export elvish | from-json)]
    if (> (count $m) 0) {
      set m = (all $m)
      keys $m | each {|k|
        if $m[$k] {
          set-env $k $m[$k]
        } else {
          unset-env $k
        }
      }
    }
  } catch e {
    echo $e
  }
}]

# ================ tool init ===================
eval (zoxide init --cmd j elvish | slurp)
