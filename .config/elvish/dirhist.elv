# dirhist.elv: fish-style directory history (prevd / nextd).

use path

var max = 50

# prev: visited directories, newest last.
# next: directories left by prevd, nearest first.
var prev = []
var next = []
# The next directory change comes from prevd/nextd and is not a new visit.
var skip = $false
var last = $pwd

fn -existing {|dirs|
  each {|d| if (path:is-dir $d) { put $d } } $dirs
}

set after-chdir = [$@after-chdir {|_|
  var old = $last
  set last = $pwd
  if $skip {
    set skip = $false
  } else {
    set prev = [$@prev $old]
    var n = (count $prev)
    if (> $n $max) {
      set prev = $prev[(- $n $max)..]
    }
    set next = []
  }
}]

fn -go {|dir|
  set skip = $true
  try {
    cd $dir
  } catch e {
    set skip = $false
    fail $e
  }
}

# Go back to the previous directory.
fn prevd {
  set prev = [(-existing $prev)]
  set next = [(-existing $next)]
  if (== (count $prev) 0) {
    return
  }
  var target = $prev[-1]
  set prev = $prev[..-1]
  set next = [$pwd $@next]
  -go $target
}

# Go forward to the directory left by prevd.
fn nextd {
  set prev = [(-existing $prev)]
  set next = [(-existing $next)]
  if (== (count $next) 0) {
    return
  }
  var target = $next[0]
  set next = $next[1..]
  set prev = [$@prev $pwd]
  -go $target
}
