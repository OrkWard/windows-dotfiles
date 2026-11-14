# rc.elv: ported from ~/.config/nushell, aligned with ~/Repos/dotfiles fish config.

use path
use runtime
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
set E:DOCKER_CONFIG = (path:join $E:XDG_CONFIG_HOME docker)

set E:CARGO_HOME = (-home .local share cargo)
set E:RUSTUP_HOME = (-home .local share rustup)
set E:MC_CONFIG_DIR = (-home .local share mc)
set E:GOPATH = (-home .local share go)
set E:GOPROXY = 'https://goproxy.cn,direct'
set E:NIMBLE_DIR = (path:join $E:XDG_DATA_HOME nimble)

set E:EDITOR = nvim
set E:BAT_THEME = GitHub
set E:FZF_DEFAULT_OPTS = "--color light --color 'fg+:red,bg+:-1' --pointer ''"
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
  (-home wpk bin) ^
  (-home .local bin) ^
  (path:join $E:GOPATH bin) ^
  (path:join $E:CARGO_HOME bin) ^
  $@paths)]

# ================ functions ===================
fn ls {|@args| e:ls --color=auto $@args }

# tree(1) layout on top of erdtree: root on top, no sizes, name order.
# Later flags win, so e.g. `tree -s rsize` still works.
fn tree {|@args| erd --layout inverted --suppress-size --sort name -L 2 $@args }

fn -now { date '+%Y-%m-%d %H:%M:%S' }

# yadm is an Elvish script in ~/.local/bin.
fn yadm {|@args|
  elvish (-home .local bin yadm.elv) $@args
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

# ================ interactive ===================
# Prompt, abbreviations, key bindings and hooks need the line editor, which
# only exists in interactive sessions.
if (not-eq $runtime:effective-rc-path $nil) {
  use ./interactive
}
