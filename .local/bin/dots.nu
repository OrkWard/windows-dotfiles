def repo-dir [] {
    $nu.home-dir | path join '.local' 'share' 'windows-dotfiles' 'repo.git'
}

def init-repo [] {
    let git_dir = (repo-dir)
    if ($git_dir | path exists) {
        error make { msg: $'repository already exists: ($git_dir)' }
    }

    mkdir ($git_dir | path dirname)
    ^git init --bare --initial-branch main $git_dir
    ^git $'--git-dir=($git_dir)' config status.showUntrackedFiles no
}

def --wrapped main [...args: string] {
    if ($args | is-empty) {
        ^git $'--git-dir=(repo-dir)' $'--work-tree=($nu.home-dir)' status --short --branch
        return
    }

    if ($args.0 == 'init') {
        if (($args | length) != 1) {
            error make { msg: 'usage: dots init' }
        }
        init-repo
        return
    }

    let git_dir = (repo-dir)
    ^git $'--git-dir=($git_dir)' $'--work-tree=($nu.home-dir)' ...$args
}
