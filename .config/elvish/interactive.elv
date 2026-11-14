# interactive.elv: prompt, abbreviations, key bindings and hooks. Everything
# here needs the line editor (edit:), so rc.elv loads it only in interactive
# sessions.

use os
use path
use platform
use re
use str
use ./osc
use ./dirhist

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
  &ycm=[&expansion='yadm commit -m "%"' &set-cursor]
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
  &gcm=[&expansion='git commit -m "%"' &set-cursor]
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
  &p0=[&expansion='%>$os:dev-null 2>&1' &set-cursor]
]

# ================ key bindings ===================
# fish-style emacs bindings, from the fork's bundled module.
use fish-binding

# Case-insensitive completion for all completion types.
set edit:completion:matcher[''] = {|seed| edit:match-prefix $seed &ignore-case }

# Ctrl-T: pick a file with fd + fzf, replacing the token left of the cursor.
set edit:insert:binding[Ctrl-T] = {
  var tok = (re:find '[^\s]*$' $edit:current-command[..$edit:-dot] | take 1)
  var picked = []
  edit:suspend-tty {
    try {
      set picked = [(fd --type f --hidden --follow --exclude .git --path-separator / |
        fzf --query=$tok[text])]
    } catch { }
  }
  if (> (count $picked) 0) {
    var cmd dot = $edit:current-command $edit:-dot
    var new = (repr $picked[0])
    set edit:current-command = $cmd[..$tok[start]]$new$cmd[$dot..]
    set edit:-dot = (+ $tok[start] (count $new))
  }
}

# Ctrl-R: search history with fzf. Enter runs the entry, Tab only puts it on
# the line, Esc keeps the line unchanged.
set edit:insert:binding[Ctrl-R] = {
  var out = ''
  edit:suspend-tty {
    try {
      set out = (edit:command-history &cmd-only &dedup &newest-first |
        each {|c| print $c"\x00" } |
        fzf --read0 --print0 --no-wrap --no-multi-line '--ellipsis=...' ^
          --scheme=history --query=$edit:current-command --expect=tab |
        slurp)
    } catch { }
  }
  if (not-eq $out '') {
    var key cmd = (str:split "\x00" $out | take 2)
    set edit:current-command = $cmd
    if (not-eq $key tab) {
      edit:return-line
    }
  }
}

# Alt-Left/Alt-B, Alt-Right/Alt-F: prevd / nextd on an empty line, word
# movement otherwise (fish's prevd-or-backward-word / nextd-or-forward-word).
fn -prevd-or-backward-word {
  if (eq $edit:current-command '') {
    dirhist:prevd
  } else {
    edit:move-dot-left-alnum-word
  }
}
fn -nextd-or-forward-word {
  if (eq $edit:current-command '') {
    dirhist:nextd
  } else {
    edit:move-dot-right-alnum-word-end
  }
}
set edit:insert:binding[Alt-Left] = $-prevd-or-backward-word~
set edit:insert:binding[Alt-b] = $-prevd-or-backward-word~
set edit:insert:binding[Alt-Right] = $-nextd-or-forward-word~
set edit:insert:binding[Alt-f] = $-nextd-or-forward-word~

# ================ hooks ===================
# Expose only the currently running command to WezTerm's session snapshot,
# and the shell's cwd so it survives commands that chdir.
set edit:after-readline = [$@edit:after-readline {|line|
  osc:set-user-var WEZTERM_LAST_COMMAND $line
}]
set edit:before-readline = [$@edit:before-readline {
  if (has-env WEZTERM_RESTORE_CWD) {
    try { cd $E:WEZTERM_RESTORE_CWD } catch { }
    unset-env WEZTERM_RESTORE_CWD
  }
  if (has-env WEZTERM_RESTORE_COMMAND) {
    set edit:current-command = $E:WEZTERM_RESTORE_COMMAND
    unset-env WEZTERM_RESTORE_COMMAND
  }
  osc:set-cwd $pwd
  osc:set-user-var WEZTERM_LAST_COMMAND ''
}]

# direnv (from `direnv hook elvish`), when it is installed.
set edit:before-readline = [$@edit:before-readline {
  if (has-external direnv) {
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
  }
}]

# OSC 133 semantic prompt: A before the prompt, C when a command starts, D with
# its exit status when it ends. B (end of prompt) needs editor support, since
# the editor draws escapes in the prompt as ^[. Kept last among the
# before-readline hooks so that nothing prints between A and the prompt.
# $-osc133-status is $nil while no command is pending; empty lines report 0.
var -osc133-status = $nil
set edit:after-readline = [$@edit:after-readline {|line|
  set -osc133-status = 0
  osc:mark-prompt C
}]
set edit:after-command = [$@edit:after-command {|m|
  if (not-eq $-osc133-status $nil) {
    set -osc133-status = $-last-status
  }
}]
set edit:before-readline = [$@edit:before-readline {
  if (not-eq $-osc133-status $nil) {
    osc:mark-prompt D $-osc133-status
    set -osc133-status = $nil
  }
  osc:mark-prompt A
}]

# ================ tool init ===================
# zoxide defines j and ji through edit:add-var.
eval (zoxide init --cmd j elvish | slurp)
