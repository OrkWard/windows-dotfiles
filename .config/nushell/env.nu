# env.nu
#
# Installed by:
# version = "0.115.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

$env.CARGO_HOME = ($env.USERPROFILE | path join '.local' 'share' 'cargo')
$env.RUSTUP_HOME = ($env.USERPROFILE | path join '.local' 'share' 'rustup')

$env.PATH = ($env.PATH
    | prepend ($env.CARGO_HOME | path join 'bin')
    | prepend ($env.USERPROFILE | path join '.local' 'bin')
    | prepend ($env.USERPROFILE | path join 'scoop' 'persist' 'nodejs' 'bin')
    | prepend ($env.USERPROFILE | path join 'scoop' 'apps' 'wezterm-nightly' 'current')
    | prepend ($env.USERPROFILE | path join 'scoop' 'shims')
    | uniq)

$env.PATHEXT = ($env.PATHEXT
    | split row ';'
    | append '.NU'
    | uniq
    | str join ';')

$env.HTTP_PROXY = 'http://proxy.lan:9090'
$env.HTTPS_PROXY = 'http://proxy.lan:9090'
$env.ALL_PROXY = 'http://proxy.lan:9090'
$env.NO_PROXY = 'localhost,127.0.0.1,::1,.lan,192.168.88.0/24,192.168.136.0/24'
$env.EDITOR = 'hx'
$env.BAT_THEME = 'GitHub'
$env.VIFM = ($env.USERPROFILE | path join '.config' 'vifm')
