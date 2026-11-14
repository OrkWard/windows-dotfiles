# yadm.elv: git on the dotfiles bare repo, with ~ as the work tree.
# Usage: elvish yadm.elv [init | git-args...]

use os
use path

var work-tree = ~
var git-dir = (path:join $work-tree .local share yadm repo.git)

# Run git, exiting with its status on failure, like a plain git call would.
fn git {|@a|
  try {
    e:git $@a
  } catch e {
    if (eq $e[reason][type] external-cmd/exited) {
      exit $e[reason][exit-status]
    }
    fail $e
  }
}

fn init-repo {
  if (os:exists $git-dir) {
    fail 'repository already exists: '$git-dir
  }
  os:mkdir-all (path:dir $git-dir)
  git init --bare $git-dir
  git --git-dir=$git-dir config status.showUntrackedFiles no
}

if (== (count $args) 0) {
  git --git-dir=$git-dir --work-tree=$work-tree status --short --branch
} elif (eq $args[0] init) {
  if (!= (count $args) 1) {
    fail 'usage: dots init'
  }
  init-repo
} else {
  git --git-dir=$git-dir --work-tree=$work-tree $@args
}
